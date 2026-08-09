import 'dart:convert';
import 'package:http/http.dart' as http;

/// Thrown for any non-2xx response. Carries the HTTP status code so
/// callers can react to specific cases (e.g. 401 -> force re-login)
/// without string-matching an error message.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class HttpService {
  final String baseUrl;

  static const Duration _timeout = Duration(seconds: 15);

  HttpService(this.baseUrl);

  Uri _buildUri(String path) {
    return Uri.parse('$baseUrl$path');
  }

  Map<String, String> _headers(String? token) {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> _handleResponse(http.Response res) async {
    dynamic decoded;

    if (res.body.isNotEmpty) {
      try {
        decoded = jsonDecode(res.body);
      } catch (_) {
        decoded = null;
      }
    }

    if (res.statusCode >= 400) {
      final message = (decoded is Map && decoded['error'] is String)
          ? decoded['error'] as String
          : 'HTTP ${res.statusCode}';

      throw ApiException(res.statusCode, message);
    }

    return decoded;
  }

  Future<Map<String, dynamic>> post(
      String path,
      Map<String, dynamic> body, {
        String? token,
      }) async {
    final res = await http
        .post(
      _buildUri(path),
      headers: _headers(token),
      body: jsonEncode(body),
    )
        .timeout(_timeout);

    final decoded = await _handleResponse(res);

    if (decoded == null) return {};
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is List) return {'items': decoded};

    throw Exception('Unexpected response format');
  }

  Future<Map<String, dynamic>> get(
      String path, {
        String? token,
      }) async {
    final res = await http
        .get(_buildUri(path), headers: _headers(token))
        .timeout(_timeout);

    final decoded = await _handleResponse(res);

    if (decoded == null) return {};
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is List) return {'items': decoded};

    throw Exception('Unexpected response format');
  }

  Future<List<dynamic>> getList(
      String path, {
        String? token,
      }) async {
    final res = await http
        .get(_buildUri(path), headers: _headers(token))
        .timeout(_timeout);

    final decoded = await _handleResponse(res);

    if (decoded == null) return [];
    if (decoded is List) return decoded;

    if (decoded is Map<String, dynamic> && decoded['items'] is List) {
      return decoded['items'];
    }

    throw Exception('Unexpected list response format');
  }
}
