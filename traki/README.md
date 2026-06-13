# Traki

Traki is a lightweight GPS proof-of-visit and workforce route tracking system built with Flutter, Node.js, SQLite, and Leaflet.js.

It is designed for:
- Security patrol teams
- Field workers
- Logistics operations
- Cleaning companies
- Inspection teams
- Distributed workforce verification

Workers start a tracking session from the mobile app, while managers monitor routes, summaries, and logs from the web dashboard.

---

# Core Advantages

## Lightweight Architecture
No Firebase.  
No Google Maps billing.  
No heavy admin panel frameworks.

Runs on:
- Small VPS servers
- Local machines
- Cheap cloud hosting

---

## Self-Hosted
You fully own:
- Backend
- Database
- Dashboard
- Mobile app source code

No recurring SaaS dependency.

---

## Zero-Config Database
Uses SQLite out of the box:
- No MySQL setup
- No PostgreSQL setup
- No external database service required

---

## No Google Maps API Costs
Traki uses:
- Leaflet.js
- OpenStreetMap

This avoids expensive Google Maps usage fees.

---

# Features

## Mobile App
- Start/end job sessions
- Automatic GPS pinging
- Live tracking
- Background-safe session handling
- Minimal one-screen UI
- Dark mode support
- Session timer
- Android support

## Dashboard
- Live job visualization
- Interactive route map
- Employee/job browser
- CSV export
- PDF report export
- Dark mode UI
- Start/end markers
- Auto-refresh every 30 seconds

## Backend
- Express.js REST API
- SQLite database
- GPS validation
- Speed anomaly protection
- Distance validation
- Rate limiting
- Lightweight architecture

---

# Tech Stack

Mobile:
- Flutter
- Riverpod

Backend:
- Node.js
- Express.js
- SQLite

Dashboard:
- HTML
- CSS
- Vanilla JavaScript
- Leaflet.js

---

# Included Features

## Mobile App
- Start/end tracking sessions
- Automatic GPS pinging
- Foreground tracking support
- Live session timer
- Dark mode UI
- Minimal one-screen workflow

## Dashboard
- Worker browser
- Job browser
- Route visualization
- Start/end route markers
- Summary statistics
- CSV export
- PDF export
- Auto-refresh every 30 seconds
- Responsive dark mode layout

## Backend
- GPS anomaly filtering
- Distance jump protection
- Speed filtering
- Rate limiting protection
- SQLite indexing

---

# Requirements

- Node.js 18+
- Flutter 3.22+
- Android SDK
- Modern browser

---

# Support

Support includes:
- Bug fixes
- Installation assistance
- Minor guidance

Customization services are not included.

---

# Important Notes


- Authentication:

Authentication is intentionally omitted to keep the backend lightweight and easy to integrate into existing systems.

Developers can easily add:

JWT auth
Firebase auth
OAuth
Session-based login systems

depending on project requirements.

- HTTPS Recommendation:

For production deployment, HTTPS is strongly recommended.

Modern Android/iOS devices may block plain HTTP traffic by default.

- Scaling Expectations:

Recommended usage scale:

Team Size	Recommendation
1–50 workers	Excellent
50–200 workers	Good with VPS
200+ workers	Recommended to migrate SQLite to PostgreSQL
---

# License

Regular Codecanyon license applies.