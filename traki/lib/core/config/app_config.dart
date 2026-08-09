class AppConfig {
  // ---------------- API ----------------
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://YOUR_SERVER_IP:8000',
  );

  // ---------------- NETWORK ----------------
  static const Duration requestTimeout =
  Duration(seconds: 10);

  // ---------------- TRACKING ----------------
  // How often we send a GPS ping while a route is active. Needs to be
  // fairly frequent so arrival/departure geofence detection feels
  // responsive while keeping network usage reasonable.
  // worker could stand at a stop for up to 2 minutes before it registers.
  static const Duration routePingInterval =
  Duration(seconds: 30);
}