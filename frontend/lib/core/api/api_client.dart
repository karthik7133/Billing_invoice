import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiResponse {
  final bool success;
  final dynamic data;
  final String? message;

  ApiResponse({required this.success, this.data, this.message});
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  String? _token;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  void setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString('auth_token', token);
    } else {
      await prefs.remove('auth_token');
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

  Future<ApiResponse> get(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url), headers: _getHeaders())
          .timeout(const Duration(seconds: 30));

      final body = json.decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(success: true, data: body);
      } else {
        return ApiResponse(
          success: false,
          message: body['message'] ?? 'Request failed with status ${response.statusCode}',
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: e.toString());
    }
  }

  Future<ApiResponse> post(String url, dynamic body) async {
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: _getHeaders(),
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 45));

      final resBody = json.decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(success: true, data: resBody);
      } else {
        return ApiResponse(
          success: false,
          message: resBody['message'] ?? 'Request failed with status ${response.statusCode}',
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: e.toString());
    }
  }

  Future<ApiResponse> put(String url, dynamic body) async {
    try {
      final response = await http
          .put(
            Uri.parse(url),
            headers: _getHeaders(),
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 45));

      final resBody = json.decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(success: true, data: resBody);
      } else {
        return ApiResponse(
          success: false,
          message: resBody['message'] ?? 'Request failed with status ${response.statusCode}',
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: e.toString());
    }
  }

  Future<ApiResponse> delete(String url) async {
    try {
      final response = await http
          .delete(Uri.parse(url), headers: _getHeaders())
          .timeout(const Duration(seconds: 30));

      final resBody = json.decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(success: true, data: resBody);
      } else {
        return ApiResponse(
          success: false,
          message: resBody['message'] ?? 'Request failed with status ${response.statusCode}',
        );
      }
    } catch (e) {
      return ApiResponse(success: false, message: e.toString());
    }
  }
}
