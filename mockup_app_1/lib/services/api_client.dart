import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../utils/retry_helper.dart';

class ApiClient {
  ApiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;
  static const Duration _requestTimeout = Duration(seconds: 20);

  Uri _uri(String path, [Map<String, String>? query]) {
    final base =
        AppConfig.apiBaseUrl.endsWith('/')
            ? AppConfig.apiBaseUrl.substring(0, AppConfig.apiBaseUrl.length - 1)
            : AppConfig.apiBaseUrl;
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Future<Map<String, String>> _headers({
    bool auth = false,
    bool includeContentType = true,
  }) async {
    final headers = <String, String>{};

    if (includeContentType) {
      headers['Content-Type'] = 'application/json';
    }

    if (auth) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You must sign in first to perform this action.');
      }
      final token = await user.getIdToken(true);
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool auth = false,
  }) async {
    try {
      return await RetryHelper.retry(
        () => _performGet(path, query, auth),
        maxAttempts: 3,
        initialDelayMs: 500,
        onRetry: (attempt, delay) {
          if (kDebugMode) {
            debugPrint(
              '[ApiClient] Retry attempt $attempt after ${delay.inMilliseconds}ms',
            );
          }
        },
      );
    } on TimeoutException {
      throw Exception(
        'Request timed out. Please check your connection and try again.',
      );
    } on SocketException {
      throw Exception(
        'Network error. Please check your connection and try again.',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ApiClient] GET Error: $e');
      }
      rethrow;
    }
  }

  Future<dynamic> _performGet(
    String path,
    Map<String, String>? query,
    bool auth,
  ) async {
    final url = _uri(path, query);
    if (kDebugMode) {
      debugPrint('[ApiClient] GET $url (auth=$auth)');
    }
    final res = await _http
        .get(url, headers: await _headers(auth: auth))
        .timeout(_requestTimeout);
    return _decode(res);
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    return await RetryHelper.retry(
      () => _performPost(path, body, auth),
      maxAttempts: 2,
      initialDelayMs: 300,
    );
  }

  Future<dynamic> _performPost(
    String path,
    Map<String, dynamic>? body,
    bool auth,
  ) async {
    final res = await _http
        .post(
          _uri(path),
          headers: await _headers(auth: auth),
          body: jsonEncode(body ?? <String, dynamic>{}),
        )
        .timeout(_requestTimeout);
    return _decode(res);
  }

  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    return await RetryHelper.retry(
      () => _performPatch(path, body, auth),
      maxAttempts: 2,
      initialDelayMs: 300,
    );
  }

  Future<dynamic> _performPatch(
    String path,
    Map<String, dynamic>? body,
    bool auth,
  ) async {
    final res = await _http
        .patch(
          _uri(path),
          headers: await _headers(auth: auth),
          body: jsonEncode(body ?? <String, dynamic>{}),
        )
        .timeout(_requestTimeout);
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    if (kDebugMode) {
      debugPrint(
        '[ApiClient] Response: ${res.statusCode} - ${res.body.substring(0, minCharacters(res.body.length, 200))}',
      );
    }

    if (res.statusCode == 401) {
      throw Exception('Your session has expired. Please sign in again.');
    }

    if (res.statusCode == 429) {
      throw Exception('Too many requests. Please wait a moment and try again.');
    }

    final data = res.body.isNotEmpty ? jsonDecode(res.body) : null;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return data;
    }

    if (data is Map && data['message'] is String) {
      final errorMsg = data['message'];
      if (kDebugMode) {
        debugPrint('[ApiClient] Error: $errorMsg');
      }
      throw Exception(errorMsg);
    }

    final errorMsg = 'Request failed (${res.statusCode})';
    if (kDebugMode) {
      debugPrint('[ApiClient] Error: $errorMsg');
    }
    throw Exception(errorMsg);
  }

  int minCharacters(int a, int b) => a < b ? a : b;

  Future<dynamic> uploadFile(
    String path, {
    required String fieldName,
    required String filePath,
    bool auth = false,
  }) async {
    final req = http.MultipartRequest('POST', _uri(path));
    req.headers.addAll(await _headers(auth: auth, includeContentType: false));
    req.files.add(await http.MultipartFile.fromPath(fieldName, filePath));

    final streamed = await req.send().timeout(_requestTimeout);
    final body = await streamed.stream.bytesToString();
    final response = http.Response(body, streamed.statusCode);
    return _decode(response);
  }
}
