import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const _jobKey =
      'active_job_id';

  static const _queueKey =
      'ping_queue';

  static const _maxQueueSize = 1000;

  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??=
    await SharedPreferences.getInstance();

    return _prefs!;
  }

  // ---------------- JOB ----------------

  Future<void> saveJobId(
      String jobId,
      ) async {
    final prefs = await _getPrefs();

    await prefs.setString(
      _jobKey,
      jobId,
    );
  }

  Future<String?> getJobId() async {
    final prefs = await _getPrefs();

    return prefs.getString(_jobKey);
  }

  Future<void> clearJobId() async {
    final prefs = await _getPrefs();

    await prefs.remove(_jobKey);
  }

  // ---------------- QUEUE ----------------

  Future<void> addPing(
      Map<String, dynamic> ping,
      ) async {
    final prefs = await _getPrefs();

    final list =
        prefs.getStringList(_queueKey) ?? [];

    if (list.length >= _maxQueueSize) {
      list.removeAt(0);
    }

    list.add(jsonEncode(ping));

    await prefs.setStringList(
      _queueKey,
      list,
    );
  }

  Future<List<Map<String, dynamic>>>
  getQueue() async {
    final prefs = await _getPrefs();

    final list =
        prefs.getStringList(_queueKey) ?? [];

    final result =
    <Map<String, dynamic>>[];

    for (final item in list) {
      try {
        final decoded =
        jsonDecode(item);

        if (decoded is Map<String, dynamic>) {
          result.add(decoded);
        }
      } catch (_) {}
    }

    return result;
  }

  Future<void> clearQueue() async {
    final prefs = await _getPrefs();

    await prefs.remove(_queueKey);
  }

  Future<void> removeFirstPing() async {
    final prefs = await _getPrefs();

    final list =
        prefs.getStringList(_queueKey) ?? [];

    if (list.isEmpty) {
      return;
    }

    list.removeAt(0);

    await prefs.setStringList(
      _queueKey,
      list,
    );
  }
}