import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Thin HTTP client. All endpoints use `/api` prefix per Developer Guidelines.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? '';

  final http.Client _client;
  final String _baseUrl;

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    final withPrefix = normalized.startsWith(AppConfig.apiPrefix)
        ? normalized
        : '${AppConfig.apiPrefix}$normalized';
    // package:http requires an absolute URI — resolve against the page origin on web.
    if (_baseUrl.isEmpty) {
      return Uri.base.replace(path: withPrefix, queryParameters: query);
    }
    return Uri.parse('$_baseUrl$withPrefix').replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    final res = await _client.get(_uri(path, query));
    if (res.statusCode >= 400) {
      throw HttpException('GET $path failed: ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final res = await _client.post(
      _uri(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body ?? {}),
    );
    if (res.statusCode >= 400) {
      throw HttpException('POST $path failed: ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  void dispose() => _client.close();
}

class HttpException implements Exception {
  HttpException(this.message);
  final String message;
  @override
  String toString() => message;
}
