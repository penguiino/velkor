import 'dart:convert';
import 'package:http/http.dart' as http;

class HttpService {
  final String baseUrl;

  static const Duration _timeout = Duration(seconds: 15);

  HttpService(this.baseUrl);

  Uri _buildUri(String path) {
    return Uri.parse('$baseUrl$path');
  }

  Future<dynamic> _handleResponse(http.Response res) async {
    if (res.statusCode >= 400) {
      throw Exception(
        'HTTP ${res.statusCode}: ${res.body.isEmpty ? "Unknown error" : res.body}',
      );
    }

    if (res.body.isEmpty) {
      return null;
    }

    try {
      return jsonDecode(res.body);
    } catch (_) {
      throw Exception('Invalid JSON response');
    }
  }

  Future<Map<String, dynamic>> post(
      String path,
      Map<String, dynamic> body,
      ) async {
    try {
      final res = await http
          .post(
        _buildUri(path),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
          .timeout(_timeout);

      final decoded = await _handleResponse(res);

      if (decoded == null) {
        return {};
      }

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      if (decoded is List) {
        return {'services': decoded};
      }

      throw Exception('Unexpected response format');
    } catch (e) {
      throw Exception('POST $path failed: $e');
    }
  }

  Future<Map<String, dynamic>> get(String path) async {
    try {
      final res = await http
          .get(_buildUri(path))
          .timeout(_timeout);

      final decoded = await _handleResponse(res);

      if (decoded == null) {
        return {};
      }

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      if (decoded is List) {
        return {'services': decoded};
      }

      throw Exception('Unexpected response format');
    } catch (e) {
      throw Exception('GET $path failed: $e');
    }
  }

  Future<List<dynamic>> getList(String path) async {
    try {
      final res = await http
          .get(_buildUri(path))
          .timeout(_timeout);

      final decoded = await _handleResponse(res);

      if (decoded == null) {
        return [];
      }

      if (decoded is List) {
        return decoded;
      }

      if (decoded is Map<String, dynamic> &&
          decoded['services'] is List) {
        return decoded['services'];
      }

      throw Exception('Unexpected list response format');
    } catch (e) {
      throw Exception('GET LIST $path failed: $e');
    }
  }
}