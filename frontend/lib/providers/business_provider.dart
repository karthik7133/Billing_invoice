import 'package:flutter/material.dart';
import '../models/business_model.dart';
import '../core/api/api_client.dart';
import '../core/api/endpoints.dart';
import '../services/local_cache_service.dart';

class BusinessProvider with ChangeNotifier {
  final ApiClient _api = ApiClient();
  final LocalCacheService _cache = LocalCacheService();

  List<BusinessModel> _companies = [];
  BusinessModel _business = BusinessModel(
    id: 'comp_1',
    businessName: 'JMJSEAFOODS',
    phone: '9344920419',
    email: '',
    address: 'Main Road',
    city: 'Kakinada',
    state: 'Andhra Pradesh',
    stateCode: '37',
    pincode: '533001',
    gstin: '37AAAAA0000A1Z5',
    pan: '',
    invoicePrefix: 'AP',
    nextInvoiceNumber: 1,
    syncOn: true,
    lastSaleCreated: '24/08/2026 at 06:07 am',
    bankDetails: BankDetails(
      bankName: 'State Bank of India',
      accountHolderName: 'JMJ SEAFOODS',
      accountNumber: '123456789012',
      ifscCode: 'SBIN0001234',
      branch: 'Main Branch',
      upiId: 'jmjseafoods@sbi',
    ),
    termsAndConditions:
        '1. Goods once sold will not be taken back or exchanged.\n2. Interest @18% p.a. will be charged if bill is not paid within 15 days.\n3. Subject to local jurisdiction only.',
  );

  bool _isLoading = false;
  String? _errorMessage;
  bool _isInitialized = false;
  late final Future<void> _initFuture;

  BusinessProvider() {
    _initFuture = _initFromCache();
  }

  /// Await this before reading business.id to ensure cache is loaded
  Future<void> ensureInitialized() => _initFuture;

  List<BusinessModel> get companies => _companies;
  BusinessModel get business => _business;
  String get activeCompanyId => _business.id;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> _initFromCache() async {
    if (_isInitialized) return;
    final cachedCompanies = await _cache.loadCompanies();
    if (cachedCompanies.isNotEmpty) {
      _companies = cachedCompanies;
    } else {
      // Default seed companies matching the reference image
      _companies = [
        _business,
        BusinessModel(
          id: 'comp_2',
          businessName: 'JJ SEA FOODS',
          phone: '9344920419',
          city: 'Visakhapatnam',
          state: 'Andhra Pradesh',
          stateCode: '37',
          invoicePrefix: 'JJ',
          syncOn: false,
          lastSaleCreated: '25/08/2026 at 09:26 am',
        ),
        BusinessModel(
          id: 'comp_3',
          businessName: 'JMJ SEA FOODS',
          phone: '9344920419',
          city: 'Chennai',
          state: 'Tamil Nadu',
          stateCode: '33',
          invoicePrefix: 'JMJ',
          syncOn: false,
          lastSaleCreated: '20/04/2026 at 10:18 am',
        ),
        BusinessModel(
          id: 'comp_4',
          businessName: 'My Company',
          phone: '9344920419',
          city: '',
          state: 'Andhra Pradesh',
          invoicePrefix: 'INV',
          syncOn: false,
          lastSaleCreated: '',
        ),
      ];
      await _cache.saveCompanies(_companies);
    }

    final activeId = await _cache.loadActiveCompanyId();
    if (activeId != null && activeId.isNotEmpty) {
      final found = _companies.firstWhere(
        (c) => c.id == activeId,
        orElse: () => _companies.first,
      );
      _business = found;
    } else {
      final cachedBusiness = await _cache.loadBusiness();
      if (cachedBusiness != null) {
        _business = cachedBusiness;
      }
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> switchToCompany(String companyId) async {
    final match = _companies.firstWhere(
      (c) => c.id == companyId,
      orElse: () => _business,
    );
    _business = match;
    await _cache.saveActiveCompanyId(companyId);
    await _cache.saveBusiness(_business);
    notifyListeners();
  }

  Future<void> addCompany(BusinessModel newCompany) async {
    _companies.add(newCompany);
    _business = newCompany;
    await _cache.saveCompanies(_companies);
    await _cache.saveActiveCompanyId(newCompany.id);
    await _cache.saveBusiness(_business);
    notifyListeners();
  }

  Future<void> updateCompany(BusinessModel updated) async {
    final idx = _companies.indexWhere(
        (c) => c.id == updated.id || (c.id == 'comp_1' && updated.id.length == 24));
    if (idx != -1) {
      _companies[idx] = updated;
    } else {
      _companies.add(updated);
    }
    if (_business.id == updated.id ||
        (_business.id == 'comp_1' && updated.id.length == 24)) {
      _business = updated;
    }
    await _cache.saveCompanies(_companies);
    await _cache.saveBusiness(_business);
    notifyListeners();
  }

  Future<void> deleteCompany(String companyId) async {
    _companies.removeWhere((c) => c.id == companyId);
    if (_companies.isEmpty) {
      _companies.add(BusinessModel(id: 'comp_default', businessName: 'My Company'));
    }
    if (_business.id == companyId) {
      _business = _companies.first;
      await _cache.saveActiveCompanyId(_business.id);
      await _cache.saveBusiness(_business);
    }
    await _cache.saveCompanies(_companies);
    notifyListeners();
  }

  Future<void> toggleCompanySync(String companyId) async {
    final idx = _companies.indexWhere((c) => c.id == companyId);
    if (idx != -1) {
      final cur = _companies[idx];
      final updated = cur.copyWith(syncOn: !cur.syncOn);
      _companies[idx] = updated;
      if (_business.id == companyId) {
        _business = updated;
      }
      await _cache.saveCompanies(_companies);
      await _cache.saveBusiness(_business);
      notifyListeners();
    }
  }

  Future<void> fetchBusinessProfile({void Function(String realId)? onIdResolved}) async {
    await _initFromCache();
    _isLoading = true;
    notifyListeners();

    final res = await _api.get(Endpoints.business);
    _isLoading = false;

    if (res.success && res.data != null && res.data['business'] != null) {
      final serverBusiness = BusinessModel.fromJson(res.data['business']);

      // 1. Update Company 1 in the companies list
      final idx = _companies.indexWhere(
          (c) => c.id == serverBusiness.id || c.id == 'comp_1');
      if (idx != -1) {
        _companies[idx] = serverBusiness;
      } else {
        _companies.insert(0, serverBusiness);
      }
      await _cache.saveCompanies(_companies);

      // 2. ONLY update active _business if the user is CURRENTLY on Company 1
      final isCurrentlyOnPrimary = _business.id.isEmpty ||
          _business.id == 'comp_1' ||
          _business.id == serverBusiness.id;

      if (isCurrentlyOnPrimary) {
        _business = serverBusiness;
        await _cache.saveBusiness(_business);
        await _cache.saveActiveCompanyId(serverBusiness.id);

        if (onIdResolved != null) {
          onIdResolved(serverBusiness.id);
        }
      }
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
    await updateCompany(_business);
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
