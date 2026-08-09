// routes/workerRoutes.js
//
// Worker-side route actions. Mounted at /worker/routes.
// Everything here requires a logged-in worker, and a worker can only
// ever act on routes assigned to themselves (checked on every endpoint).

const express = require('express');
const { requireWorker } = require('../middleware/auth');
const { all, get, run } = require('../utils/dbAsync');
const { distance, GPS_ANOMALY } = require('../utils/helpers');
const {
  getStops,
  findCurrentStop,
  findNextStop,
  maybeCompleteRoute,
} = require('../utils/routeLogic');

const router = express.Router();

router.use(requireWorker);

function toPublicStop(row) {
  return {
    id: row.id,
    orderIndex: row.order_index,
    customerName: row.customer_name,
    address: row.address,
    lat: row.lat,
    lng: row.lng,
    notes: row.notes,
    geofenceRadiusM: row.geofence_radius_m,
    status: row.status,
    arrivedAt: row.arrived_at,
    departedAt: row.departed_at,
  };
}

async function toPublicRoute(route) {
  const stops = await getStops(route.id);
  const current = findCurrentStop(stops);
  const next = findNextStop(stops, current);

  return {
    id: route.id,
    name: route.name,
    routeDate: route.route_date,
    status: route.status,
    startedAt: route.started_at,
    completedAt: route.completed_at,
    stops: stops.map(toPublicStop),
    currentStopId: current ? current.id : null,
    nextStopId: next ? next.id : null,
    completedStopCount: stops.filter((s) =>
      ['completed', 'skipped'].includes(s.status)
    ).length,
    totalStopCount: stops.length,
  };
}

// Fetches a route and 404s / 403s if it doesn't belong to this worker.
async function loadOwnRoute(req, res) {
  const route = await get(`SELECT * FROM routes WHERE id = ?`, [req.params.id]);

  if (!route) {
    res.status(404).json({ error: 'Route not found' });
    return null;
  }

  if (route.worker_id !== req.auth.sub) {
    res.status(403).json({ error: 'This route is not assigned to you' });
    return null;
  }

  return route;
}

// -------------------- TODAY'S ROUTE --------------------

router.get('/today', async (req, res) => {
  try {
    const today = new Date().toISOString().slice(0, 10);

    const route = await get(
      `
        SELECT * FROM routes
        WHERE worker_id = ? AND route_date = ?
        ORDER BY created_at DESC
        LIMIT 1
      `,
      [req.auth.sub, today]
    );

    if (!route) {
      return res.status(404).json({ error: 'No route assigned for today' });
    }

    res.json(await toPublicRoute(route));
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// -------------------- START ROUTE --------------------

router.post('/:id/start', async (req, res) => {
  try {
    const route = await loadOwnRoute(req, res);
    if (!route) return;

    if (route.status === 'completed') {
      return res.status(409).json({ error: 'This route has already been completed' });
    }

    if (route.status === 'pending') {
      await run(
        `UPDATE routes SET status = 'active', started_at = ? WHERE id = ?`,
        [Date.now(), route.id]
      );
    }

    const updated = await get(`SELECT * FROM routes WHERE id = ?`, [route.id]);

    res.json(await toPublicRoute(updated));
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// -------------------- GPS PING (auto arrival/departure detection) --------------------

router.post('/:id/ping', async (req, res) => {
  try {
    const route = await loadOwnRoute(req, res);
    if (!route) return;

    if (route.status !== 'active') {
      return res.status(409).json({ error: 'Route is not active' });
    }

    const { lat, lng } = req.body || {};

    if (lat == null || lng == null) {
      return res.status(400).json({ error: 'lat and lng are required' });
    }

    const now = Date.now();

    // Ignore pings that imply an impossible jump or speed since the last breadcrumb.
    const lastLog = await get(
      `SELECT * FROM location_logs WHERE route_id = ? ORDER BY timestamp DESC LIMIT 1`,
      [route.id]
    );

    if (lastLog) {
      const dist = distance(lastLog.lat, lastLog.lng, lat, lng);
      const timeDiffS = (now - lastLog.timestamp) / 1000;
      const speed = dist / Math.max(timeDiffS, 1);

      if (dist > GPS_ANOMALY.MAX_JUMP_METERS || speed > GPS_ANOMALY.MAX_SPEED_MPS) {
        return res.json({ success: true, ignored: true });
      }
    }

    await run(
      `INSERT INTO location_logs (route_id, lat, lng, timestamp) VALUES (?, ?, ?, ?)`,
      [route.id, lat, lng, now]
    );

    // ---- Geofence-based arrival/departure detection ----

    const stops = await getStops(route.id);
    const current = findCurrentStop(stops);

    let event = null;

    if (current) {
      const distToStop = distance(lat, lng, current.lat, current.lng);
      const withinGeofence = distToStop <= current.geofence_radius_m;

      if (current.status === 'pending' && withinGeofence) {
        await run(
          `UPDATE stops SET status = 'arrived', arrived_at = ? WHERE id = ?`,
          [now, current.id]
        );
        event = 'arrived';
      } else if (current.status === 'arrived' && !withinGeofence) {
        await run(
          `UPDATE stops SET status = 'completed', departed_at = ? WHERE id = ?`,
          [now, current.id]
        );
        await maybeCompleteRoute(route.id);
        event = 'departed';
      }
    }

    const updatedRoute = await get(`SELECT * FROM routes WHERE id = ?`, [route.id]);

    res.json({
      success: true,
      event,
      route: await toPublicRoute(updatedRoute),
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// -------------------- MANUAL ARRIVE OVERRIDE --------------------
// For when GPS detection fails (weak signal, indoor location, etc).

router.post('/:id/stops/:stopId/arrive', async (req, res) => {
  try {
    const route = await loadOwnRoute(req, res);
    if (!route) return;

    const stop = await get(`SELECT * FROM stops WHERE id = ? AND route_id = ?`, [
      req.params.stopId,
      route.id,
    ]);

    if (!stop) return res.status(404).json({ error: 'Stop not found' });

    if (stop.status !== 'pending') {
      return res.status(409).json({ error: `Stop is already ${stop.status}` });
    }

    await run(
      `UPDATE stops SET status = 'arrived', arrived_at = ?, manual_override = 1 WHERE id = ?`,
      [Date.now(), stop.id]
    );

    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// -------------------- MANUAL DEPART OVERRIDE --------------------

router.post('/:id/stops/:stopId/depart', async (req, res) => {
  try {
    const route = await loadOwnRoute(req, res);
    if (!route) return;

    const stop = await get(`SELECT * FROM stops WHERE id = ? AND route_id = ?`, [
      req.params.stopId,
      route.id,
    ]);

    if (!stop) return res.status(404).json({ error: 'Stop not found' });

    if (stop.status !== 'arrived') {
      return res.status(409).json({
        error: `Stop must be 'arrived' before it can depart (currently ${stop.status})`,
      });
    }

    await run(
      `UPDATE stops SET status = 'completed', departed_at = ?, manual_override = 1 WHERE id = ?`,
      [Date.now(), stop.id]
    );

    const completed = await maybeCompleteRoute(route.id);

    res.json({ success: true, routeCompleted: completed });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
