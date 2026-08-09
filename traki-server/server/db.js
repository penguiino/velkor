// db.js
// Central SQLite connection + full schema for Velkor (formerly Traki).
//
// Schema notes:
// - `managers`       : dashboard login accounts
// - `workers`        : field worker accounts (worker_code + PIN login)
// - `routes`         : a day's assigned work for one worker
// - `stops`          : individual customer visits inside a route
// - `location_logs`  : GPS breadcrumb trail while a route is active
// - `revoked_tokens` : JWTs explicitly invalidated by logout

const sqlite3 = require('sqlite3').verbose();

const db = new sqlite3.Database('./database.db');

db.serialize(() => {
  db.run(`PRAGMA foreign_keys = ON`);

  // -------------------- MANAGERS --------------------

  db.run(`
    CREATE TABLE IF NOT EXISTS managers (
      id TEXT PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      created_at INTEGER NOT NULL
    )
  `);

  // -------------------- WORKERS --------------------

  db.run(`
    CREATE TABLE IF NOT EXISTS workers (
      id TEXT PRIMARY KEY,
      worker_code TEXT UNIQUE NOT NULL,
      name TEXT NOT NULL,
      pin_hash TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'active',
      created_by TEXT REFERENCES managers(id),
      created_at INTEGER NOT NULL
    )
  `);

  db.run(`CREATE INDEX IF NOT EXISTS idx_workers_code ON workers(worker_code)`);

  // -------------------- ROUTES --------------------

  db.run(`
    CREATE TABLE IF NOT EXISTS routes (
      id TEXT PRIMARY KEY,
      worker_id TEXT NOT NULL REFERENCES workers(id),
      name TEXT,
      route_date TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      started_at INTEGER,
      completed_at INTEGER,
      created_by TEXT REFERENCES managers(id),
      created_at INTEGER NOT NULL
    )
  `);

  db.run(`CREATE INDEX IF NOT EXISTS idx_routes_worker ON routes(worker_id)`);
  db.run(`CREATE INDEX IF NOT EXISTS idx_routes_date ON routes(route_date)`);

  // -------------------- STOPS --------------------

  db.run(`
    CREATE TABLE IF NOT EXISTS stops (
      id TEXT PRIMARY KEY,
      route_id TEXT NOT NULL REFERENCES routes(id),
      order_index INTEGER NOT NULL,
      customer_name TEXT NOT NULL,
      address TEXT,
      lat REAL NOT NULL,
      lng REAL NOT NULL,
      notes TEXT,
      geofence_radius_m INTEGER NOT NULL DEFAULT 75,
      status TEXT NOT NULL DEFAULT 'pending',
      arrived_at INTEGER,
      departed_at INTEGER,
      manual_override INTEGER NOT NULL DEFAULT 0
    )
  `);

  db.run(`CREATE INDEX IF NOT EXISTS idx_stops_route ON stops(route_id)`);

  // -------------------- LOCATION LOGS (route breadcrumbs) --------------------

  db.run(`
    CREATE TABLE IF NOT EXISTS location_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      route_id TEXT NOT NULL REFERENCES routes(id),
      lat REAL NOT NULL,
      lng REAL NOT NULL,
      timestamp INTEGER NOT NULL
    )
  `);

  db.run(`CREATE INDEX IF NOT EXISTS idx_loclogs_route ON location_logs(route_id)`);
  db.run(`CREATE INDEX IF NOT EXISTS idx_loclogs_time ON location_logs(timestamp)`);

  // -------------------- REVOKED TOKENS (logout support) --------------------

  db.run(`
    CREATE TABLE IF NOT EXISTS revoked_tokens (
      jti TEXT PRIMARY KEY,
      expires_at INTEGER NOT NULL
    )
  `);
});

module.exports = db;
