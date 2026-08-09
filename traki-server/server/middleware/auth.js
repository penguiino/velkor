// middleware/auth.js

const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const db = require('../db');

// In production, set JWT_SECRET as an environment variable.
// Falling back to a random per-process secret means old tokens
// won't survive a server restart if you forget to set it -- that's
// intentional, it's safer than shipping a hardcoded default secret.
const JWT_SECRET =
  process.env.JWT_SECRET ||
  crypto.randomBytes(48).toString('hex');

const MANAGER_TOKEN_TTL = '12h';
const WORKER_TOKEN_TTL = '30d'; // workers stay logged in across app restarts

function signManagerToken(manager) {
  return jwt.sign(
    { sub: manager.id, role: 'manager', email: manager.email, jti: crypto.randomUUID() },
    JWT_SECRET,
    { expiresIn: MANAGER_TOKEN_TTL }
  );
}

function signWorkerToken(worker) {
  return jwt.sign(
    { sub: worker.id, role: 'worker', workerCode: worker.worker_code, jti: crypto.randomUUID() },
    JWT_SECRET,
    { expiresIn: WORKER_TOKEN_TTL }
  );
}

function extractToken(req) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');

  if (scheme !== 'Bearer' || !token) {
    return null;
  }

  return token;
}

function isRevoked(jti) {
  return new Promise((resolve) => {
    db.get(
      `SELECT jti FROM revoked_tokens WHERE jti = ?`,
      [jti],
      (err, row) => resolve(!!row)
    );
  });
}

function verifyRole(requiredRole) {
  return async (req, res, next) => {
    const token = extractToken(req);

    if (!token) {
      return res.status(401).json({ error: 'Missing token' });
    }

    let payload;

    try {
      payload = jwt.verify(token, JWT_SECRET);
    } catch (e) {
      return res.status(401).json({ error: 'Invalid or expired token' });
    }

    if (payload.role !== requiredRole) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    if (await isRevoked(payload.jti)) {
      return res.status(401).json({ error: 'Token has been revoked' });
    }

    req.auth = payload;
    req.rawToken = token;

    next();
  };
}

function revokeToken(payload) {
  return new Promise((resolve, reject) => {
    db.run(
      `INSERT OR REPLACE INTO revoked_tokens (jti, expires_at) VALUES (?, ?)`,
      [payload.jti, (payload.exp || 0) * 1000],
      (err) => (err ? reject(err) : resolve())
    );
  });
}

// Best-effort cleanup so the revoked_tokens table doesn't grow forever.
// Runs occasionally, not on every request.
function pruneExpiredRevocations() {
  db.run(`DELETE FROM revoked_tokens WHERE expires_at < ?`, [Date.now()]);
}

module.exports = {
  JWT_SECRET,
  signManagerToken,
  signWorkerToken,
  requireManager: verifyRole('manager'),
  requireWorker: verifyRole('worker'),
  revokeToken,
  pruneExpiredRevocations,
};
