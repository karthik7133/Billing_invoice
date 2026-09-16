import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/business_model.dart';
import '../core/api/api_client.dart';
import '../core/api/endpoints.dart';
import '../services/local_cache_service.dart';
import '../services/backend_sync_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiClient _api = ApiClient();
  final LocalCacheService _cache = LocalCacheService();

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

  /// Checks for a stored token and loads cached user/business profile immediately
  Future<void> checkAuthStatus() async {
    debugPrint('[AuthProvider] checkAuthStatus starting...');
    await _api.init();
    await _cache.init();

    _user = await _cache.loadUser();
    _business = await _cache.loadBusiness();

    if (_api.token != null && _api.token!.isNotEmpty) {
      debugPrint('[AuthProvider] Found saved token, authenticating user');
      _isAuthenticated = true;
    } else {
      debugPrint('[AuthProvider] No saved token found');
      _isAuthenticated = false;
    }
    _hasCheckedAuth = true;
    notifyListeners();

    // Start proactive early warm-up for Render backend
    BackendSyncService.instance.startEarlyWarmup();
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
    debugPrint('[AuthProvider] register() called for email: $email, name: $name');
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
      debugPrint('[AuthProvider] Registration SUCCESS! Token received.');
      _api.setToken(res.data['token']);
      _user = UserModel.fromJson(res.data['user']);
      if (res.data['business'] != null) {
        _business = BusinessModel.fromJson(res.data['business']);
      }
      if (_user != null) await _cache.saveUser(_user!);
      if (_business != null) await _cache.saveBusiness(_business!);

      _isAuthenticated = true;
      _errorMessage = null;
      notifyListeners();
      return true;
    } else {
      debugPrint('[AuthProvider] Registration FAILED: ${res.message}');
      _errorMessage = res.message ?? 'Registration failed. Server may still be waking up. Please retry.';
      _isAuthenticated = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    debugPrint('[AuthProvider] login() called for email: $email');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _api.post(Endpoints.login, {
      'email': email,
      'password': password,
    });

    _isLoading = false;

    if (res.success && res.data != null && res.data['token'] != null) {
      debugPrint('[AuthProvider] Login SUCCESS! Token received.');
      _api.setToken(res.data['token']);
      _user = UserModel.fromJson(res.data['user']);
      if (res.data['business'] != null) {
        _business = BusinessModel.fromJson(res.data['business']);
      }
      if (_user != null) await _cache.saveUser(_user!);
      if (_business != null) await _cache.saveBusiness(_business!);

      _isAuthenticated = true;
      _errorMessage = null;
      notifyListeners();
      return true;
    } else {
      debugPrint('[AuthProvider] Login FAILED: ${res.message}');
      _errorMessage = res.message ?? 'Invalid email or password. Server may still be waking up.';
      _isAuthenticated = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchMe() async {
    debugPrint('[AuthProvider] fetchMe() called');
    final res = await _api.get(Endpoints.me);
    if (res.success && res.data != null) {
      if (res.data['user'] != null) {
        _user = UserModel.fromJson(res.data['user']);
        await _cache.saveUser(_user!);
      }
      if (res.data['business'] != null) {
        _business = BusinessModel.fromJson(res.data['business']);
        await _cache.saveBusiness(_business!);
      }
      notifyListeners();
    }
  }

  void logout() {
    debugPrint('[AuthProvider] logout() called');
    _api.setToken(null);
    _user = null;
    _business = null;
    _isAuthenticated = false;
    _errorMessage = null;
    _cache.clearAll();
    notifyListeners();
  }
}
