// server.js

const express = require('express');
const cors = require('cors');
const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const rateLimit = require('express-rate-limit');

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

// -------------------- DB --------------------

const db = new sqlite3.Database('./database.db');

db.serialize(() => {

  db.run(`PRAGMA foreign_keys = ON`);

  db.run(`
    CREATE TABLE IF NOT EXISTS jobs (
      id TEXT PRIMARY KEY,
      worker_id TEXT,
      start_lat REAL,
      start_lng REAL,
      end_lat REAL,
      end_lng REAL,
      started_at INTEGER,
      ended_at INTEGER
    )
  `);

  db.run(`
    CREATE TABLE IF NOT EXISTS job_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      job_id TEXT REFERENCES jobs(id),
      lat REAL,
      lng REAL,
      timestamp INTEGER
    )
  `);

  db.run(`
    CREATE INDEX IF NOT EXISTS idx_jobs_worker
    ON jobs(worker_id)
  `);

  db.run(`
    CREATE INDEX IF NOT EXISTS idx_logs_job
    ON job_logs(job_id)
  `);

  db.run(`
    CREATE INDEX IF NOT EXISTS idx_logs_time
    ON job_logs(timestamp)
  `);
});

// -------------------- HELPERS --------------------

function generateId() {
  return Math.random()
    .toString(36)
    .substring(2, 11);
}

function distance(lat1, lon1, lat2, lon2) {

  const R = 6371e3;

  const toRad = (x) =>
    (x * Math.PI) / 180;

  const dLat =
    toRad(lat2 - lat1);

  const dLon =
    toRad(lon2 - lon1);

  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) *
    Math.cos(toRad(lat2)) *
    Math.sin(dLon / 2) ** 2;

  return (
    R *
    2 *
    Math.atan2(
      Math.sqrt(a),
      Math.sqrt(1 - a)
    )
  );
}

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

// -------------------- START JOB --------------------

app.post('/start-job', (req, res) => {

  const {
   workerId,
   lat,
   lng,
  } = req.body || {};

  if (
    !workerId ||
    lat == null ||
    lng == null
  ) {
    return res
      .status(400)
      .send('Invalid data');
  }

  const now = Date.now();

  db.get(
    `
      SELECT id
      FROM jobs
      WHERE worker_id = ?
      AND ended_at IS NULL
    `,
    [workerId],

    (err, existing) => {

      if (err) {
        return res
          .status(500)
          .send(err.message);
      }

      if (existing) {

        return res.json({
          jobId: existing.id,
          alreadyActive: true,
        });
      }

      const jobId =
        generateId();

      db.serialize(() => {

        db.run(
          `
            INSERT INTO jobs (
              id,
              worker_id,
              start_lat,
              start_lng,
              started_at
            )
            VALUES (?, ?, ?, ?, ?)
          `,
          [
            jobId,
            workerId,
            lat,
            lng,
            now,
          ]
        );

        db.run(
          `
            INSERT INTO job_logs (
              job_id,
              lat,
              lng,
              timestamp
            )
            VALUES (?, ?, ?, ?)
          `,
          [
            jobId,
            lat,
            lng,
            now,
          ]
        );
      });


      res.json({
        jobId,
        alreadyActive: false,
      });
    }
  );
});

// -------------------- JOB PING --------------------

app.post('/job-ping', (req, res) => {

  const {
   jobId,
   lat,
   lng,
  } = req.body || {};

  if (
    !jobId ||
    lat == null ||
    lng == null
  ) {
    return res
      .status(400)
      .send('Invalid data');
  }

  const now = Date.now();

  db.get(
    `SELECT * FROM jobs WHERE id = ?`,
    [jobId],

    (err, job) => {

      if (err) {
        return res
          .status(500)
          .send(err.message);
      }

      if (!job) {
        return res
          .status(404)
          .send('Job not found');
      }

      if (job.ended_at) {

        return res.json({
          success: true,
          alreadyEnded: true,
        });
      }

      db.get(
        `
          SELECT *
          FROM job_logs
          WHERE job_id = ?
          ORDER BY timestamp DESC
          LIMIT 1
        `,
        [jobId],

        (err, lastLog) => {

          if (err) {
            return res
              .status(500)
              .send(err.message);
          }

          if (lastLog) {

            const dist = distance(
              lastLog.lat,
              lastLog.lng,
              lat,
              lng
            );

            const timeDiff =
              (now - lastLog.timestamp) / 1000;

            const speed =
              dist / Math.max(timeDiff, 1);

            if (
              dist > MAX_JUMP ||
              speed > MAX_SPEED
            ) {

              return res.json({
                success: true,
                ignored: true,
              });
            }
          }

          db.run(
            `
              INSERT INTO job_logs (
                job_id,
                lat,
                lng,
                timestamp
              )
              VALUES (?, ?, ?, ?)
            `,
            [
              jobId,
              lat,
              lng,
              now,
            ],

            (err) => {

              if (err) {
                return res
                  .status(500)
                  .send(err.message);
              }

              res.json({
                success: true,
              });
            }
          );
        }
      );
    }
  );
});

// -------------------- END JOB --------------------

app.post('/end-job', (req, res) => {

  const {
   jobId,
   lat,
   lng,
  } = req.body || {};

  if (
    !jobId ||
    lat == null ||
    lng == null
  ) {
    return res
      .status(400)
      .send('Invalid data');
  }

  const now = Date.now();

  db.get(
    `SELECT * FROM jobs WHERE id = ?`,
    [jobId],

    (err, job) => {

      if (err) {
        return res
          .status(500)
          .send(err.message);
      }

      if (!job) {
        return res
          .status(404)
          .send('Job not found');
      }

      if (job.ended_at) {

        return res.json({
          success: true,
          alreadyEnded: true,
        });
      }

      db.get(
        `
          SELECT COUNT(*) as count
          FROM job_logs
          WHERE job_id = ?
        `,
        [jobId],

        (err, result) => {

          if (err) {
            return res
              .status(500)
              .send(err.message);
          }

          const duration =
            now - job.started_at;

          if (
            result.count < MIN_LOGS ||
            duration < MIN_DURATION
          ) {

            return res
              .status(400)
              .json({
                error:
                  'Insufficient proof of work',
                logs: result.count,
                duration,
              });
          }

          db.run(
            `
              UPDATE jobs
              SET
                end_lat = ?,
                end_lng = ?,
                ended_at = ?
              WHERE id = ?
            `,
            [
              lat,
              lng,
              now,
              jobId,
            ],

            function (err) {

              if (err) {
                return res
                  .status(500)
                  .send(err.message);
              }


              res.json({
                success: true,
              });
            }
          );
        }
      );
    }
  );
});

// -------------------- WORKERS --------------------

app.get('/workers', (req, res) => {

  db.all(
    `
      SELECT DISTINCT worker_id
      FROM jobs
    `,
    [],

    (err, rows) => {

      if (err) {
        return res
          .status(500)
          .send(err.message);
      }

      res.json(
        rows.map(
          (r) => r.worker_id
        )
      );
    }
  );
});

// -------------------- JOBS --------------------

app.get('/jobs', (req, res) => {

  const { workerId } =
    req.query;

  let query =
    `SELECT * FROM jobs`;

  const params = [];

  if (workerId) {

    query +=
      ` WHERE worker_id = ?`;

    params.push(workerId);
  }

  query +=
    ` ORDER BY started_at DESC`;

  db.all(
    query,
    params,

    (err, rows) => {

      if (err) {
        return res
          .status(500)
          .send(err.message);
      }

      res.json(rows);
    }
  );
});

// -------------------- JOB LOGS --------------------

app.get('/job/:id/logs', (req, res) => {

  const jobId =
    req.params.id;

  db.all(
    `
      SELECT *
      FROM job_logs
      WHERE job_id = ?
      ORDER BY timestamp ASC
    `,
    [jobId],

    (err, rows) => {

      if (err) {
        return res
          .status(500)
          .send(err.message);
      }

      res.json(rows);
    }
  );
});

// -------------------- JOB SUMMARY --------------------

app.get('/job/:id/summary', (req, res) => {

  const jobId =
    req.params.id;

  db.get(
    `SELECT * FROM jobs WHERE id = ?`,
    [jobId],

    (err, job) => {

      if (err) {
        return res
          .status(500)
          .send(err.message);
      }

      if (!job) {

        return res
          .status(404)
          .send('Job not found');
      }

      db.all(
        `
          SELECT lat, lng
          FROM job_logs
          WHERE job_id = ?
          ORDER BY timestamp ASC
        `,
        [jobId],

        (err, logs) => {

          if (err) {
            return res
              .status(500)
              .send(err.message);
          }

          let totalDistance = 0;

          for (
            let i = 1;
            i < logs.length;
            i++
          ) {

            totalDistance += distance(
              logs[i - 1].lat,
              logs[i - 1].lng,
              logs[i].lat,
              logs[i].lng
            );
          }

          res.json({
            jobId,

            workerId:
              job.worker_id,

            startedAt:
              job.started_at,

            endedAt:
              job.ended_at,

            durationMs:
              (
                job.ended_at ||
                Date.now()
              ) - job.started_at,

            pingCount:
              logs.length,

            totalDistanceMeters:
              Math.round(totalDistance),
          });
        }
      );
    }
  );
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