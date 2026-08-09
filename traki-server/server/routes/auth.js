// routes/auth.js

const express = require('express');
const bcrypt = require('bcryptjs');
const db = require('../db');
const { generateId } = require('../utils/helpers');
const {
  signManagerToken,
  signWorkerToken,
  requireManager,
  revokeToken,
} = require('../middleware/auth');

const router = express.Router();

// -------------------- MANAGER REGISTER --------------------
// Intentionally locked to "only works while there are zero managers".
// This gives you a one-time setup endpoint to create the first admin
// account without exposing open self-registration in production.
// Additional managers should be created by an existing manager (not
// implemented yet -- flagging for a later milestone if you want multiple
// manager accounts).

router.post('/manager/register', (req, res) => {
  const { email, password } = req.body || {};

  if (!email || !password || password.length < 8) {
    return res.status(400).json({
      error: 'Email and a password (min 8 chars) are required',
    });
  }

  db.get(`SELECT COUNT(*) as count FROM managers`, [], (err, row) => {
    if (err) return res.status(500).json({ error: err.message });

    if (row.count > 0) {
      return res.status(403).json({
        error: 'Setup already completed. Ask an existing manager for access.',
      });
    }

    const hash = bcrypt.hashSync(password, 10);
    const id = generateId();

    db.run(
      `INSERT INTO managers (id, email, password_hash, created_at) VALUES (?, ?, ?, ?)`,
      [id, email.toLowerCase().trim(), hash, Date.now()],
      function (err) {
        if (err) {
          if (String(err.message).includes('UNIQUE')) {
            return res.status(409).json({ error: 'Email already in use' });
          }
          return res.status(500).json({ error: err.message });
        }

        const token = signManagerToken({ id, email });

        res.json({ token, manager: { id, email } });
      }
    );
  });
});

// -------------------- MANAGER LOGIN --------------------

router.post('/manager/login', (req, res) => {
  const { email, password } = req.body || {};

  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password are required' });
  }

  db.get(
    `SELECT * FROM managers WHERE email = ?`,
    [email.toLowerCase().trim()],
    (err, manager) => {
      if (err) return res.status(500).json({ error: err.message });

      if (!manager || !bcrypt.compareSync(password, manager.password_hash)) {
        return res.status(401).json({ error: 'Invalid email or password' });
      }

      const token = signManagerToken(manager);

      res.json({
        token,
        manager: { id: manager.id, email: manager.email },
      });
    }
  );
});

// -------------------- MANAGER LOGOUT --------------------

router.post('/manager/logout', requireManager, async (req, res) => {
  try {
    await revokeToken(req.auth);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// -------------------- WORKER LOGIN --------------------

router.post('/worker/login', (req, res) => {
  const { workerCode, pin } = req.body || {};

  if (!workerCode || !pin) {
    return res.status(400).json({ error: 'Worker ID and PIN are required' });
  }

  db.get(
    `SELECT * FROM workers WHERE worker_code = ?`,
    [workerCode.trim()],
    (err, worker) => {
      if (err) return res.status(500).json({ error: err.message });

      if (!worker || !bcrypt.compareSync(String(pin), worker.pin_hash)) {
        return res.status(401).json({ error: 'Invalid Worker ID or PIN' });
      }

      if (worker.status !== 'active') {
        return res.status(403).json({ error: 'This worker account is disabled' });
      }

      const token = signWorkerToken(worker);

      res.json({
        token,
        worker: {
          id: worker.id,
          workerCode: worker.worker_code,
          name: worker.name,
        },
      });
    }
  );
});

module.exports = router;
