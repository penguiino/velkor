import 'package:shared_preferences/shared_preferences.dart';

class AuthStorageService {
  static const _tokenKey = 'worker_token';
  static const _workerIdKey = 'worker_id';
  static const _workerCodeKey = 'worker_code';
  static const _workerNameKey = 'worker_name';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> saveSession({
    required String token,
    required String workerId,
    required String workerCode,
    required String workerName,
  }) async {
    final prefs = await _getPrefs();

    await prefs.setString(_tokenKey, token);
    await prefs.setString(_workerIdKey, workerId);
    await prefs.setString(_workerCodeKey, workerCode);
    await prefs.setString(_workerNameKey, workerName);
  }

  Future<String?> getToken() async {
    final prefs = await _getPrefs();
    return prefs.getString(_tokenKey);
  }

  Future<String?> getWorkerName() async {
    final prefs = await _getPrefs();
    return prefs.getString(_workerNameKey);
  }

  Future<String?> getWorkerCode() async {
    final prefs = await _getPrefs();
    return prefs.getString(_workerCodeKey);
  }

  Future<void> clear() async {
    final prefs = await _getPrefs();

    await prefs.remove(_tokenKey);
    await prefs.remove(_workerIdKey);
    await prefs.remove(_workerCodeKey);
    await prefs.remove(_workerNameKey);
  }
}
