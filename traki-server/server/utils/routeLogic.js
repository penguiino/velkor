// utils/routeLogic.js

const { all, run } = require('./dbAsync');

const ACTIVE_STOP_STATUSES = ['pending', 'arrived'];
const RESOLVED_STOP_STATUSES = ['completed', 'skipped'];

async function getStops(routeId) {
  return all(
    `SELECT * FROM stops WHERE route_id = ? ORDER BY order_index ASC`,
    [routeId]
  );
}

// The stop the worker is currently working on: the first one (in order)
// that hasn't been resolved yet.
function findCurrentStop(stops) {
  return stops.find((s) => ACTIVE_STOP_STATUSES.includes(s.status)) || null;
}

// The stop after the current one, for "upcoming stops" display.
function findNextStop(stops, currentStop) {
  if (!currentStop) return null;

  return (
    stops.find(
      (s) =>
        s.order_index > currentStop.order_index &&
        !RESOLVED_STOP_STATUSES.includes(s.status)
    ) || null
  );
}

// Call after any stop transitions to completed/skipped. Marks the route
// completed once every stop is resolved -- this is what makes "route
// completes when every stop has been visited" automatic.
async function maybeCompleteRoute(routeId) {
  const stops = await getStops(routeId);

  if (stops.length === 0) return false;

  const allResolved = stops.every((s) =>
    RESOLVED_STOP_STATUSES.includes(s.status)
  );

  if (!allResolved) return false;

  await run(
    `UPDATE routes SET status = 'completed', completed_at = ? WHERE id = ? AND status != 'completed'`,
    [Date.now(), routeId]
  );

  return true;
}

module.exports = {
  ACTIVE_STOP_STATUSES,
  RESOLVED_STOP_STATUSES,
  getStops,
  findCurrentStop,
  findNextStop,
  maybeCompleteRoute,
};
