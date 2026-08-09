// server.js

const express = require('express');
const cors = require('cors');
const path = require('path');
const rateLimit = require('express-rate-limit');

const db = require('./db');
const { pruneExpiredRevocations } = require('./middleware/auth');

const authRouter = require('./routes/auth');
const workersRouter = require('./routes/workers');
const adminRoutesRouter = require('./routes/routes');
const workerRoutesRouter = require('./routes/workerRoutes');

const app = express();

// -------------------- CONFIG --------------------

const PORT = process.env.PORT || 8000;

const HOST = process.env.HOST || '0.0.0.0';

// -------------------- MIDDLEWARE --------------------

app.use(cors());

app.use(express.json());

app.use(express.static(path.join(__dirname, 'public')));

// Basic protection against spam requests

app.use(
  rateLimit({
    windowMs: 60 * 1000,
    max: 300,
  })
);

// -------------------- AUTH & WORKER MANAGEMENT --------------------
// (DB schema now lives in ./db.js — managers, workers, routes, stops,
// location_logs, revoked_tokens are all created there.)

app.use('/auth', authRouter);

// Manager-facing worker management.
app.use('/admin/workers', workersRouter);
app.use('/admin/routes', adminRoutesRouter);
app.use('/worker/routes', workerRoutesRouter);

// Clear out expired logout-revocation records periodically instead of on
// every request.
setInterval(pruneExpiredRevocations, 60 * 60 * 1000);

// -------------------- VALIDATION LIMITS --------------------

const MAX_SPEED = 80;

const MAX_JUMP = 5000;

const MIN_DURATION = 2 * 60 * 1000;

const MIN_LOGS = 1;

// -------------------- HEALTH CHECK --------------------

app.get('/health', (req, res) => {

  res.json({
    ok: true,
    timestamp: Date.now(),
  });
});

// -------------------- START SERVER --------------------

app.listen(
  PORT,
  HOST,

  () => {

    console.log(
      `Server running on http://${HOST}:${PORT}`
    );
  }
);