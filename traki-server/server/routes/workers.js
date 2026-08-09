// routes/workers.js

const express = require('express');
const bcrypt = require('bcryptjs');
const db = require('../db');
const { generateId } = require('../utils/helpers');
const { requireManager } = require('../middleware/auth');

const router = express.Router();

// All worker-management endpoints require a logged-in manager.
router.use(requireManager);

function isValidPin(pin) {
  if (pin === null || pin === undefined) return false;
  return /^\d{4,8}$/.test(String(pin));
}

function toPublicWorker(row) {
  return {
    id: row.id,
    workerCode: row.worker_code,
    name: row.name,
    status: row.status,
    createdAt: row.created_at,
  };
}

// -------------------- CREATE WORKER --------------------

router.post('/', (req, res) => {
  const { workerCode, name, pin } = req.body || {};

  if (!workerCode || !name || !pin) {
    return res.status(400).json({ error: 'workerCode, name and pin are required' });
  }

  if (!isValidPin(pin)) {
    return res.status(400).json({ error: 'PIN must be 4-8 digits' });
  }

  const id = generateId();
  const pinHash = bcrypt.hashSync(String(pin), 10);

  db.run(
    `
      INSERT INTO workers (id, worker_code, name, pin_hash, status, created_by, created_at)
      VALUES (?, ?, ?, ?, 'active', ?, ?)
    `,
    [id, workerCode.trim(), name.trim(), pinHash, req.auth.sub, Date.now()],
    function (err) {
      if (err) {
        if (String(err.message).includes('UNIQUE')) {
          return res.status(409).json({ error: 'Worker ID already in use' });
        }
        return res.status(500).json({ error: err.message });
      }

      db.get(`SELECT * FROM workers WHERE id = ?`, [id], (err, row) => {
        if (err) return res.status(500).json({ error: err.message });
        res.status(201).json(toPublicWorker(row));
      });
    }
  );
});

// -------------------- LIST WORKERS --------------------

router.get('/', (req, res) => {
  db.all(`SELECT * FROM workers ORDER BY created_at DESC`, [], (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows.map(toPublicWorker));
  });
});

// -------------------- GET ONE WORKER --------------------

router.get('/:id', (req, res) => {
  db.get(`SELECT * FROM workers WHERE id = ?`, [req.params.id], (err, row) => {
    if (err) return res.status(500).json({ error: err.message });
    if (!row) return res.status(404).json({ error: 'Worker not found' });
    res.json(toPublicWorker(row));
  });
});

// -------------------- EDIT WORKER (name / workerCode) --------------------

router.patch('/:id', (req, res) => {
  const { name, workerCode } = req.body || {};

  if (!name && !workerCode) {
    return res.status(400).json({ error: 'Nothing to update' });
  }

  const fields = [];
  const params = [];

  if (name) {
    fields.push('name = ?');
    params.push(name.trim());
  }

  if (workerCode) {
    fields.push('worker_code = ?');
    params.push(workerCode.trim());
  }

  params.push(req.params.id);

  db.run(
    `UPDATE workers SET ${fields.join(', ')} WHERE id = ?`,
    params,
    function (err) {
      if (err) {
        if (String(err.message).includes('UNIQUE')) {
          return res.status(409).json({ error: 'Worker ID already in use' });
        }
        return res.status(500).json({ error: err.message });
      }

      if (this.changes === 0) {
        return res.status(404).json({ error: 'Worker not found' });
      }

      db.get(`SELECT * FROM workers WHERE id = ?`, [req.params.id], (err, row) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(toPublicWorker(row));
      });
    }
  );
});

// -------------------- DISABLE / RE-ENABLE WORKER --------------------

router.patch('/:id/status', (req, res) => {
  const { status } = req.body || {};

  if (!['active', 'disabled'].includes(status)) {
    return res.status(400).json({ error: "status must be 'active' or 'disabled'" });
  }

  db.run(
    `UPDATE workers SET status = ? WHERE id = ?`,
    [status, req.params.id],
    function (err) {
      if (err) return res.status(500).json({ error: err.message });

      if (this.changes === 0) {
        return res.status(404).json({ error: 'Worker not found' });
      }

      res.json({ success: true, status });
    }
  );
});

// -------------------- RESET PIN --------------------

router.post('/:id/reset-pin', (req, res) => {
  const { pin } = req.body || {};

  if (!isValidPin(pin)) {
    return res.status(400).json({ error: 'PIN must be 4-8 digits' });
  }

  const pinHash = bcrypt.hashSync(String(pin), 10);

  db.run(
    `UPDATE workers SET pin_hash = ? WHERE id = ?`,
    [pinHash, req.params.id],
    function (err) {
      if (err) return res.status(500).json({ error: err.message });

      if (this.changes === 0) {
        return res.status(404).json({ error: 'Worker not found' });
      }

      res.json({ success: true });
    }
  );
});

module.exports = router;
