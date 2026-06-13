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
  static const Duration pingInterval =
  Duration(minutes: 2);
}