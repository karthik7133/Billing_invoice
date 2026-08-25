import 'package:flutter/material.dart';
import '../models/business_model.dart';
import '../core/api/api_client.dart';
import '../core/api/endpoints.dart';
import '../services/local_cache_service.dart';

class BusinessProvider with ChangeNotifier {
  final ApiClient _api = ApiClient();
  final LocalCacheService _cache = LocalCacheService();

  BusinessModel _business = BusinessModel(
    id: '',
    businessName: '',
    phone: '',
    email: '',
    address: '',
    city: '',
    state: 'Andhra Pradesh',
    stateCode: '37',
    pincode: '',
    gstin: '',
    pan: '',
    invoicePrefix: 'INV',
    nextInvoiceNumber: 1,
    bankDetails: BankDetails(
      bankName: '',
      accountHolderName: '',
      accountNumber: '',
      ifscCode: '',
      branch: '',
      upiId: '',
    ),
    termsAndConditions:
        '1. Goods once sold will not be taken back or exchanged.\n2. Interest @18% p.a. will be charged if bill is not paid within 15 days.\n3. Subject to local jurisdiction only.',
  );

  bool _isLoading = false;
  String? _errorMessage;
  bool _isInitialized = false;

  BusinessProvider() {
    _initFromCache();
  }

  Future<void> _initFromCache() async {
    if (_isInitialized) return;
    final cached = await _cache.loadBusiness();
    if (cached != null) {
      _business = cached;
      notifyListeners();
    }
    _isInitialized = true;
  }

  BusinessModel get business => _business;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchBusinessProfile() async {
    await _initFromCache();
    _isLoading = true;
    notifyListeners();

    final res = await _api.get(Endpoints.business);
    _isLoading = false;

    if (res.success && res.data != null && res.data['business'] != null) {
      _business = BusinessModel.fromJson(res.data['business']);
      await _cache.saveBusiness(_business);
    }
    notifyListeners();
  }

  Future<bool> updateBusinessProfile(BusinessModel updated) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _api.put(Endpoints.business, updated.toJson());
    _isLoading = false;

    if (res.success && res.data != null && res.data['business'] != null) {
      _business = BusinessModel.fromJson(res.data['business']);
    } else {
      _business = updated;
    }
    await _cache.saveBusiness(_business);
    notifyListeners();
    return true;
  }

  void updateLogo(String logoUrl) {
    _business = _business.copyWith(logo: logoUrl);
    updateBusinessProfile(_business);
    notifyListeners();
  }

  void incrementNextInvoiceNumber() {
    _business = _business.copyWith(nextInvoiceNumber: _business.nextInvoiceNumber + 1);
    updateBusinessProfile(_business);
    notifyListeners();
  }
}
