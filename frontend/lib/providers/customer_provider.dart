import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/customer_model.dart';
import '../core/api/api_client.dart';
import '../core/api/endpoints.dart';
import '../services/local_cache_service.dart';

class CustomerProvider with ChangeNotifier {
  final ApiClient _api = ApiClient();
  final LocalCacheService _cache = LocalCacheService();
  final _uuid = const Uuid();

  List<CustomerModel> _customers = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  bool _isInitialized = false;

  /// The active company ID — set when the user switches companies
  String _activeCompanyId = '';

  CustomerProvider() {
    _initFromCache();
  }

  /// Called by ManageCompaniesScreen / BusinessProvider when active company changes
  void setActiveCompany(String companyId) {
    _activeCompanyId = companyId;
    _customers = [];
    _isInitialized = false;
    notifyListeners();
  }

  Future<void> _initFromCache() async {
    if (_isInitialized) return;
    final cached = await _cache.loadCustomers(companyId: _activeCompanyId);
    if (cached.isNotEmpty && _customers.isEmpty) {
      _customers = cached;
      notifyListeners();
    }
    _isInitialized = true;
  }

  List<CustomerModel> get customers {
    if (_searchQuery.isEmpty) return _customers;
    return _customers.where((c) {
      final name = c.name.toLowerCase();
      final phone = c.phone.toLowerCase();
      final gstin = c.gstin.toLowerCase();
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || phone.contains(q) || gstin.contains(q);
    }).toList();
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setSearchQuery(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  Future<void> fetchCustomers() async {
    await _initFromCache();
    _isLoading = true;
    notifyListeners();

    // Build URL with companyId query param if set
    final url = _activeCompanyId.isNotEmpty
        ? '${Endpoints.customers}?companyId=$_activeCompanyId'
        : Endpoints.customers;

    final res = await _api.get(url);
    _isLoading = false;

    if (res.success && res.data != null && res.data['customers'] != null) {
      final list = (res.data['customers'] as List)
          .map((c) => CustomerModel.fromJson(c as Map<String, dynamic>))
          .toList();
      _customers = list;
      await _cache.saveCustomers(_customers, companyId: _activeCompanyId);
    }
    notifyListeners();
  }

  CustomerModel? getCustomerById(String id) {
    try {
      return _customers.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  CustomerModel? findByName(String name) {
    try {
      final q = name.trim().toLowerCase();
      return _customers.firstWhere((c) => c.name.trim().toLowerCase() == q);
    } catch (_) {
      return null;
    }
  }

  Future<CustomerModel?> addCustomer(CustomerModel newCustomer) async {
    _isLoading = true;
    notifyListeners();

    CustomerModel finalCustomer = newCustomer.id.isNotEmpty ? newCustomer : newCustomer.copyWith(id: _uuid.v4());

    // Add companyId to the payload
    final payload = {
      ...newCustomer.toJson(),
      if (_activeCompanyId.isNotEmpty) 'companyId': _activeCompanyId,
    };

    final res = await _api.post(Endpoints.customers, payload);
    _isLoading = false;

    if (res.success && res.data != null && res.data['customer'] != null) {
      finalCustomer = CustomerModel.fromJson(res.data['customer']);
    }

    final existingIdx = _customers.indexWhere(
        (c) => c.id == finalCustomer.id || c.name.toLowerCase() == finalCustomer.name.toLowerCase());
    if (existingIdx != -1) {
      _customers[existingIdx] = finalCustomer;
    } else {
      _customers.insert(0, finalCustomer);
    }

    await _cache.saveCustomers(_customers, companyId: _activeCompanyId);
    notifyListeners();
    return finalCustomer;
  }

  void updatePartyBalanceFromInvoice(String customerId, double newDueAmount) {
    final index = _customers.indexWhere((c) => c.id == customerId);
    if (index != -1) {
      final current = _customers[index];
      _customers[index] = current.copyWith(
        balance: current.balance + newDueAmount,
        lastTransactionDate: DateTime.now(),
      );
      _cache.saveCustomers(_customers, companyId: _activeCompanyId);
      notifyListeners();
    }
  }

  Future<bool> updateCustomer(CustomerModel updated) async {
    _isLoading = true;
    notifyListeners();

    if (updated.id.isNotEmpty) {
      final payload = {
        ...updated.toJson(),
        if (_activeCompanyId.isNotEmpty) 'companyId': _activeCompanyId,
      };
      await _api.put('${Endpoints.customers}/${updated.id}', payload);
    }
    _isLoading = false;

    final index = _customers.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      _customers[index] = updated;
      await _cache.saveCustomers(_customers, companyId: _activeCompanyId);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> deleteCustomer(String id) async {
    final target = getCustomerById(id);
    final targetName = target?.name.trim().toLowerCase();

    _customers.removeWhere(
        (c) => c.id == id || (targetName != null && c.name.trim().toLowerCase() == targetName));
    await _cache.saveCustomers(_customers, companyId: _activeCompanyId);
    notifyListeners();

    if (id.isNotEmpty) {
      await _api.delete('${Endpoints.customers}/$id');
    }
    return true;
  }
}
