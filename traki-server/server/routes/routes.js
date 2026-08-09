// routes/routes.js
//
// Manager-side route & stop management. Mounted at /admin/routes.
// Everything here requires a logged-in manager.

const express = require('express');
const { requireManager } = require('../middleware/auth');
const { all, get, run } = require('../utils/dbAsync');
const { distance, generateId } = require('../utils/helpers');
const { getStops, findCurrentStop, findNextStop } = require('../utils/routeLogic');

const router = express.Router();

router.use(requireManager);

const EDITABLE_STATUSES = ['pending'];

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
    manualOverride: !!row.manual_override,
  };
}

function toPublicRoute(row, stops) {
  const current = stops ? findCurrentStop(stops) : null;
  const next = stops ? findNextStop(stops, current) : null;

  return {
    id: row.id,
    workerId: row.worker_id,
    name: row.name,
    routeDate: row.route_date,
    status: row.status,
    startedAt: row.started_at,
    completedAt: row.completed_at,
    createdAt: row.created_at,
    ...(stops
      ? {
          stops: stops.map(toPublicStop),
          currentStopId: current ? current.id : null,
          nextStopId: next ? next.id : null,
          completedStopCount: stops.filter((s) =>
            ['completed', 'skipped'].includes(s.status)
          ).length,
          totalStopCount: stops.length,
        }
      : {}),
  };
}

// -------------------- CREATE ROUTE (with stops) --------------------

router.post('/', async (req, res) => {
  try {
    const { workerId, name, routeDate, stops } = req.body || {};

    if (!workerId || !routeDate || !Array.isArray(stops) || stops.length === 0) {
      return res.status(400).json({
        error: 'workerId, routeDate and a non-empty stops array are required',
      });
    }

    const worker = await get(`SELECT * FROM workers WHERE id = ?`, [workerId]);

    if (!worker) {
      return res.status(404).json({ error: 'Worker not found' });
    }

    for (const [i, stop] of stops.entries()) {
      if (!stop.customerName || stop.lat == null || stop.lng == null) {
        return res.status(400).json({
          error: `Stop ${i + 1} is missing customerName, lat, or lng`,
        });
      }
    }

    const routeId = generateId();

    await run(
      `
        INSERT INTO routes (id, worker_id, name, route_date, status, created_by, created_at)
        VALUES (?, ?, ?, ?, 'pending', ?, ?)
      `,
      [routeId, workerId, name || null, routeDate, req.auth.sub, Date.now()]
    );

    for (const [i, stop] of stops.entries()) {
      await run(
        `
          INSERT INTO stops (
            id, route_id, order_index, customer_name, address,
            lat, lng, notes, geofence_radius_m, status
          )
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')
        `,
        [
          generateId(),
          routeId,
          i,
          stop.customerName.trim(),
          stop.address || null,
          stop.lat,
          stop.lng,
          stop.notes || null,
          stop.geofenceRadiusM || 75,
        ]
      );
    }

    const routeRow = await get(`SELECT * FROM routes WHERE id = ?`, [routeId]);
    const stopRows = await getStops(routeId);

    res.status(201).json(toPublicRoute(routeRow, stopRows));
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// -------------------- LIVE STATUS (for dashboard) --------------------
// Defined before "/:id" so Express doesn't treat "live" as a route id.

router.get('/live', async (req, res) => {
  try {
    const routes = await all(
      `SELECT * FROM routes WHERE status = 'active' ORDER BY started_at ASC`
    );

    const ONLINE_THRESHOLD_MS = 5 * 60 * 1000; // last ping within 5 min = online
    const now = Date.now();

    const result = [];

    for (const route of routes) {
      const stops = await getStops(route.id);
      const current = findCurrentStop(stops);
      const next = findNextStop(stops, current);

      const lastLog = await get(
        `SELECT * FROM location_logs WHERE route_id = ? ORDER BY timestamp DESC LIMIT 1`,
        [route.id]
      );

      const worker = await get(`SELECT * FROM workers WHERE id = ?`, [route.worker_id]);

      result.push({
        routeId: route.id,
        workerId: route.worker_id,
        workerName: worker ? worker.name : null,
        routeName: route.name,
        startedAt: route.started_at,
        currentStop: current ? toPublicStop(current) : null,
        nextStop: next ? toPublicStop(next) : null,
        completedStopCount: stops.filter((s) =>
          ['completed', 'skipped'].includes(s.status)
        ).length,
        totalStopCount: stops.length,
        lastLocation: lastLog ? { lat: lastLog.lat, lng: lastLog.lng } : null,
        lastUpdate: lastLog ? lastLog.timestamp : null,
        online: lastLog ? now - lastLog.timestamp < ONLINE_THRESHOLD_MS : false,
      });
    }

    res.json(result);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// -------------------- LIST ROUTES --------------------

router.get('/', async (req, res) => {
  try {
    const { workerId, routeDate, status } = req.query;

    let query = `SELECT * FROM routes WHERE 1=1`;
    const params = [];

    if (workerId) {
      query += ` AND worker_id = ?`;
      params.push(workerId);
    }

    if (routeDate) {
      query += ` AND route_date = ?`;
      params.push(routeDate);
    }

    if (status) {
      query += ` AND status = ?`;
      params.push(status);
    }

    query += ` ORDER BY route_date DESC, created_at DESC`;

    const rows = await all(query, params);

    const withStops = await Promise.all(
      rows.map(async (row) => {
        const stops = await getStops(row.id);
        return toPublicRoute(row, stops);
      })
    );

    res.json(withStops);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// -------------------- GET ROUTE DETAIL --------------------

router.get('/:id', async (req, res) => {
  try {
    const route = await get(`SELECT * FROM routes WHERE id = ?`, [req.params.id]);

    if (!route) {
      return res.status(404).json({ error: 'Route not found' });
    }

    const stops = await getStops(route.id);

    res.json(toPublicRoute(route, stops));
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// -------------------- EDIT ROUTE METADATA --------------------
// Only while the route hasn't started -- once a worker is out on the
// route, changing the plan underneath them would corrupt the history.

router.patch('/:id', async (req, res) => {
  try {
    const route = await get(`SELECT * FROM routes WHERE id = ?`, [req.params.id]);

    if (!route) {
      return res.status(404).json({ error: 'Route not found' });
    }

    if (!EDITABLE_STATUSES.includes(route.status)) {
      return res.status(409).json({
        error: `Route cannot be edited once it is ${route.status}`,
      });
    }

    const { name, routeDate, workerId } = req.body || {};
    const fields = [];
    const params = [];

    if (name !== undefined) {
      fields.push('name = ?');
      params.push(name);
    }

    if (routeDate) {
      fields.push('route_date = ?');
      params.push(routeDate);
    }

    if (workerId) {
      const worker = await get(`SELECT id FROM workers WHERE id = ?`, [workerId]);
      if (!worker) return res.status(404).json({ error: 'Worker not found' });
      fields.push('worker_id = ?');
      params.push(workerId);
    }

    if (fields.length === 0) {
      return res.status(400).json({ error: 'Nothing to update' });
    }

    params.push(req.params.id);

    await run(`UPDATE routes SET ${fields.join(', ')} WHERE id = ?`, params);

    const updated = await get(`SELECT * FROM routes WHERE id = ?`, [req.params.id]);
    const stops = await getStops(req.params.id);

    res.json(toPublicRoute(updated, stops));
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// -------------------- DELETE ROUTE --------------------

router.delete('/:id', async (req, res) => {
  try {
    const route = await get(`SELECT * FROM routes WHERE id = ?`, [req.params.id]);

    if (!route) {
      return res.status(404).json({ error: 'Route not found' });
    }

    if (!EDITABLE_STATUSES.includes(route.status)) {
      return res.status(409).json({
        error: `Route cannot be deleted once it is ${route.status}`,
      });
    }

    await run(`DELETE FROM stops WHERE route_id = ?`, [req.params.id]);
    await run(`DELETE FROM location_logs WHERE route_id = ?`, [req.params.id]);
    await run(`DELETE FROM routes WHERE id = ?`, [req.params.id]);

    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// -------------------- ADD A STOP --------------------

router.post('/:id/stops', async (req, res) => {
  try {
    const route = await get(`SELECT * FROM routes WHERE id = ?`, [req.params.id]);

    if (!route) return res.status(404).json({ error: 'Route not found' });

    if (!EDITABLE_STATUSES.includes(route.status)) {
      return res.status(409).json({
        error: `Stops cannot be added once the route is ${route.status}`,
      });
    }

    const { customerName, address, lat, lng, notes, geofenceRadiusM } = req.body || {};

    if (!customerName || lat == null || lng == null) {
      return res.status(400).json({ error: 'customerName, lat and lng are required' });
    }

    const existing = await getStops(req.params.id);
    const nextOrder = existing.length;

    const stopId = generateId();

    await run(
      `
        INSERT INTO stops (
          id, route_id, order_index, customer_name, address,
          lat, lng, notes, geofence_radius_m, status
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')
      `,
      [
        stopId,
        req.params.id,
        nextOrder,
        customerName.trim(),
        address || null,
        lat,
        lng,
        notes || null,
        geofenceRadiusM || 75,
      ]
    );

    const stop = await get(`SELECT * FROM stops WHERE id = ?`, [stopId]);

    res.status(201).json(toPublicStop(stop));
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// -------------------- EDIT A STOP --------------------

router.patch('/:id/stops/:stopId', async (req, res) => {
  try {
    const route = await get(`SELECT * FROM routes WHERE id = ?`, [req.params.id]);

    if (!route) return res.status(404).json({ error: 'Route not found' });

    if (!EDITABLE_STATUSES.includes(route.status)) {
      return res.status(409).json({
        error: `Stops cannot be edited once the route is ${route.status}`,
      });
    }

    const stop = await get(`SELECT * FROM stops WHERE id = ? AND route_id = ?`, [
      req.params.stopId,
      req.params.id,
    ]);

    if (!stop) return res.status(404).json({ error: 'Stop not found' });

    const { customerName, address, lat, lng, notes, geofenceRadiusM } = req.body || {};

    const fields = [];
    const params = [];

    if (customerName) {
      fields.push('customer_name = ?');
      params.push(customerName.trim());
    }
    if (address !== undefined) {
      fields.push('address = ?');
      params.push(address);
    }
    if (lat != null) {
      fields.push('lat = ?');
      params.push(lat);
    }
    if (lng != null) {
      fields.push('lng = ?');
      params.push(lng);
    }
    if (notes !== undefined) {
      fields.push('notes = ?');
      params.push(notes);
    }
    if (geofenceRadiusM != null) {
      fields.push('geofence_radius_m = ?');
      params.push(geofenceRadiusM);
    }

    if (fields.length === 0) {
      return res.status(400).json({ error: 'Nothing to update' });
    }

    params.push(req.params.stopId);

    await run(`UPDATE stops SET ${fields.join(', ')} WHERE id = ?`, params);

    const updated = await get(`SELECT * FROM stops WHERE id = ?`, [req.params.stopId]);

    res.json(toPublicStop(updated));
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// -------------------- DELETE A STOP --------------------

router.delete('/:id/stops/:stopId', async (req, res) => {
  try {
    const route = await get(`SELECT * FROM routes WHERE id = ?`, [req.params.id]);

    if (!route) return res.status(404).json({ error: 'Route not found' });

    if (!EDITABLE_STATUSES.includes(route.status)) {
      return res.status(409).json({
        error: `Stops cannot be removed once the route is ${route.status}`,
      });
    }

    const result = await run(`DELETE FROM stops WHERE id = ? AND route_id = ?`, [
      req.params.stopId,
      req.params.id,
    ]);

    if (result.changes === 0) {
      return res.status(404).json({ error: 'Stop not found' });
    }

    // Re-sequence order_index so there are no gaps after a delete.
    const remaining = await getStops(req.params.id);

    for (const [i, s] of remaining.entries()) {
      if (s.order_index !== i) {
        await run(`UPDATE stops SET order_index = ? WHERE id = ?`, [i, s.id]);
      }
    }

    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// -------------------- ROUTE LOCATION LOGS (breadcrumb trail) --------------------

router.get('/:id/logs', async (req, res) => {
  try {
    const route = await get(`SELECT id FROM routes WHERE id = ?`, [req.params.id]);

    if (!route) return res.status(404).json({ error: 'Route not found' });

    const logs = await all(
      `SELECT lat, lng, timestamp FROM location_logs WHERE route_id = ? ORDER BY timestamp ASC`,
      [req.params.id]
    );

    res.json(logs);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// -------------------- ROUTE SUMMARY REPORT --------------------

router.get('/:id/summary', async (req, res) => {
  try {
    const route = await get(`SELECT * FROM routes WHERE id = ?`, [req.params.id]);

    if (!route) return res.status(404).json({ error: 'Route not found' });

    const stops = await getStops(route.id);

    const logs = await all(
      `SELECT lat, lng FROM location_logs WHERE route_id = ? ORDER BY timestamp ASC`,
      [route.id]
    );

    let totalDistance = 0;

    for (let i = 1; i < logs.length; i++) {
      totalDistance += distance(
        logs[i - 1].lat,
        logs[i - 1].lng,
        logs[i].lat,
        logs[i].lng
      );
    }

    const worker = await get(`SELECT * FROM workers WHERE id = ?`, [route.worker_id]);

    res.json({
      routeId: route.id,
      routeName: route.name,
      workerId: route.worker_id,
      workerName: worker ? worker.name : null,
      status: route.status,
      startedAt: route.started_at,
      completedAt: route.completed_at,
      durationMs: route.started_at
        ? (route.completed_at || Date.now()) - route.started_at
        : null,
      totalStops: stops.length,
      completedStops: stops.filter((s) => s.status === 'completed').length,
      skippedStops: stops.filter((s) => s.status === 'skipped').length,
      distanceMeters: Math.round(totalDistance),
      stops: stops.map((s) => ({
        customerName: s.customer_name,
        address: s.address,
        status: s.status,
        arrivedAt: s.arrived_at,
        departedAt: s.departed_at,
        manualOverride: !!s.manual_override,
      })),
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
