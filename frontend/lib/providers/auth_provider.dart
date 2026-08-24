import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/business_model.dart';
import '../core/api/api_client.dart';
import '../core/api/endpoints.dart';

class AuthProvider with ChangeNotifier {
  final ApiClient _api = ApiClient();

  UserModel? _user;
  BusinessModel? _business;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isAuthenticated = false;
  bool _hasCheckedAuth = false;

  UserModel? get user => _user;
  BusinessModel? get business => _business;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _isAuthenticated;
  bool get hasCheckedAuth => _hasCheckedAuth;

  /// Checks for a stored token on startup.
  /// Does NOT make a network call — trusts the stored token immediately.
  /// Token will be naturally validated on the first real API call.
  Future<void> checkAuthStatus() async {
    await _api.init();
    if (_api.token != null && _api.token!.isNotEmpty) {
      _isAuthenticated = true;
    } else {
      _isAuthenticated = false;
    }
    _hasCheckedAuth = true;
    notifyListeners();
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? businessName,
    String? state,
    String? gstin,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _api.post(Endpoints.register, {
      'name': name,
      'email': email,
      'password': password,
      'phone': phone ?? '',
      'businessName': businessName ?? '$name Enterprise',
      'state': state ?? 'Andhra Pradesh',
      'gstin': gstin ?? '',
    });

    _isLoading = false;

    if (res.success && res.data != null && res.data['token'] != null) {
      _api.setToken(res.data['token']);
      _user = UserModel.fromJson(res.data['user']);
      if (res.data['business'] != null) {
        _business = BusinessModel.fromJson(res.data['business']);
      }
      _isAuthenticated = true;
      _errorMessage = null;
      notifyListeners();
      return true;
    } else {
      _errorMessage = res.message ?? 'Registration failed. Please check your details and try again.';
      _isAuthenticated = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _api.post(Endpoints.login, {
      'email': email,
      'password': password,
    });

    _isLoading = false;

    if (res.success && res.data != null && res.data['token'] != null) {
      _api.setToken(res.data['token']);
      _user = UserModel.fromJson(res.data['user']);
      if (res.data['business'] != null) {
        _business = BusinessModel.fromJson(res.data['business']);
      }
      _isAuthenticated = true;
      _errorMessage = null;
      notifyListeners();
      return true;
    } else {
      _errorMessage = res.message ?? 'Invalid email or password.';
      _isAuthenticated = false;
      notifyListeners();
      return false;
    }
  }

  /// Demo mode — no account needed, local-only data
  void loginAsDemo() {
    _user = UserModel(
      id: 'user_demo',
      name: 'Demo User',
      email: 'demo@billing.app',
      phone: '',
    );
    _isAuthenticated = true;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> fetchMe() async {
    final res = await _api.get(Endpoints.me);
    if (res.success && res.data != null) {
      if (res.data['user'] != null) {
        _user = UserModel.fromJson(res.data['user']);
      }
      if (res.data['business'] != null) {
        _business = BusinessModel.fromJson(res.data['business']);
      }
      notifyListeners();
    }
  }

  void logout() {
    _api.setToken(null);
    _user = null;
    _business = null;
    _isAuthenticated = false;
    _errorMessage = null;
    notifyListeners();
  }
}
