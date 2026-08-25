import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiResponse {
  final bool success;
  final dynamic data;
  final String? message;
  final int? statusCode;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.statusCode,
  });
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  String? _token;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    debugPrint('[ApiClient] Initialized with token: ${_token != null ? "Present (${_token!.substring(0, _token!.length > 10 ? 10 : _token!.length)}...)" : "None"}');
  }

  void setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString('auth_token', token);
      debugPrint('[ApiClient] Saved auth token');
    } else {
      await prefs.remove('auth_token');
      debugPrint('[ApiClient] Cleared auth token');
    }
  }

  String? get token => _token;

  Map<String, String> _getHeaders({bool isJson = true}) {
    final headers = <String, String>{};
    if (isJson) {
      headers['Content-Type'] = 'application/json';
    }
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  /// Executes an HTTP action with smart retry logic for Render free-tier cold starts
  Future<ApiResponse> _executeWithRetry(
    String method,
    String url,
    Future<http.Response> Function() action, {
    int maxRetries = 2,
  }) async {
    int attempt = 0;
    while (attempt <= maxRetries) {
      attempt++;
      try {
        debugPrint('[API $method] Attempt $attempt/$maxRetries -> $url');
        final response = await action();
        debugPrint('[API $method] Response (${response.statusCode}) <- $url');

        // Check if server is returning 502/503/504 Bad Gateway (Render container starting up)
        if ((response.statusCode == 502 || response.statusCode == 503 || response.statusCode == 504) && attempt <= maxRetries) {
          debugPrint('[API $method] Render server is starting up (${response.statusCode}). Retrying in 2.5s...');
          await Future.delayed(const Duration(milliseconds: 2500));
          continue;
        }

        final body = json.decode(response.body);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return ApiResponse(success: true, data: body, statusCode: response.statusCode);
        } else {
          return ApiResponse(
            success: false,
            message: body['message'] ?? 'Request failed with status ${response.statusCode}',
            statusCode: response.statusCode,
          );
        }
      } on SocketException catch (e) {
        debugPrint('[API $method] SocketException on attempt $attempt: $e');
        if (attempt <= maxRetries) {
          await Future.delayed(const Duration(milliseconds: 2500));
          continue;
        }
        return ApiResponse(
          success: false,
          message: 'Connection failed. Server may still be waking up. Please try again in a moment.',
        );
      } on TimeoutException catch (e) {
        debugPrint('[API $method] Timeout on attempt $attempt: $e');
        if (attempt <= maxRetries) {
          await Future.delayed(const Duration(milliseconds: 2000));
          continue;
        }
        return ApiResponse(
          success: false,
          message: 'Request timed out while waiting for server to wake up.',
        );
      } catch (e) {
        debugPrint('[API $method] Error: $e');
        if (attempt <= maxRetries && e.toString().contains('Failed host lookup')) {
          await Future.delayed(const Duration(milliseconds: 2000));
          continue;
        }
        return ApiResponse(success: false, message: e.toString());
      }
    }

    return ApiResponse(
      success: false,
      message: 'Server is currently waking up. Please retry.',
    );
  }

  Future<ApiResponse> get(String url) async {
    return _executeWithRetry('GET', url, () {
      return http
          .get(Uri.parse(url), headers: _getHeaders())
          .timeout(const Duration(seconds: 40));
    });
  }

  Future<ApiResponse> post(String url, dynamic body) async {
    return _executeWithRetry('POST', url, () {
      return http
          .post(
            Uri.parse(url),
            headers: _getHeaders(),
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 45));
    });
  }

  Future<ApiResponse> put(String url, dynamic body) async {
    return _executeWithRetry('PUT', url, () {
      return http
          .put(
            Uri.parse(url),
            headers: _getHeaders(),
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 45));
    });
  }

  Future<ApiResponse> delete(String url) async {
    return _executeWithRetry('DELETE', url, () {
      return http
          .delete(Uri.parse(url), headers: _getHeaders())
          .timeout(const Duration(seconds: 30));
    });
  }

  /// Upload file to Cloudinary / Backend upload route
  Future<ApiResponse> uploadFile(String url, String filePath, {String fieldName = 'file'}) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(url));
      if (_token != null && _token!.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $_token';
      }
      request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));
      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);
      final body = json.decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(success: true, data: body, statusCode: response.statusCode);
      } else {
        return ApiResponse(
          success: false,
          message: body['message'] ?? 'File upload failed (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('[API UPLOAD] Error: $e');
      return ApiResponse(success: false, message: e.toString());
    }
  }

  /// Upload raw bytes or web file to Cloudinary
  Future<ApiResponse> uploadBytes(String url, List<int> bytes, String filename, {String fieldName = 'file'}) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(url));
      if (_token != null && _token!.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $_token';
      }
      request.files.add(http.MultipartFile.fromBytes(fieldName, bytes, filename: filename));
      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);
      final body = json.decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(success: true, data: body, statusCode: response.statusCode);
      } else {
        return ApiResponse(
          success: false,
          message: body['message'] ?? 'File upload failed (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('[API UPLOAD] Error: $e');
      return ApiResponse(success: false, message: e.toString());
    }
  }
}
