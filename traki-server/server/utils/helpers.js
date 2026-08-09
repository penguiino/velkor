// utils/helpers.js

function generateId() {
  return (
    Math.random().toString(36).substring(2, 11) +
    Math.random().toString(36).substring(2, 6)
  );
}

// Haversine distance in meters
function distance(lat1, lon1, lat2, lon2) {
  const R = 6371e3;

  const toRad = (x) => (x * Math.PI) / 180;

  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);

  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLon / 2) ** 2;

  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// Basic GPS anomaly thresholds for route tracking.
const GPS_ANOMALY = {
  MAX_SPEED_MPS: 80, // ~288 km/h
  MAX_JUMP_METERS: 5000,
};

module.exports = { generateId, distance, GPS_ANOMALY };
