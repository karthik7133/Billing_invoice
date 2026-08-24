import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/customer_model.dart';
import '../core/api/api_client.dart';
import '../core/api/endpoints.dart';

class CustomerProvider with ChangeNotifier {
  final ApiClient _api = ApiClient();
  final _uuid = const Uuid();

  List<CustomerModel> _customers = [];

  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';

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
    _isLoading = true;
    notifyListeners();

    final res = await _api.get(Endpoints.customers);
    _isLoading = false;

    if (res.success && res.data != null && res.data['customers'] != null) {
      final list = (res.data['customers'] as List)
          .map((c) => CustomerModel.fromJson(c as Map<String, dynamic>))
          .toList();
      _customers = list;
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

    final res = await _api.post(Endpoints.customers, newCustomer.toJson());
    _isLoading = false;

    if (res.success && res.data != null && res.data['customer'] != null) {
      finalCustomer = CustomerModel.fromJson(res.data['customer']);
    }

    // Check if already in list
    final existingIdx = _customers.indexWhere((c) => c.id == finalCustomer.id || c.name.toLowerCase() == finalCustomer.name.toLowerCase());
    if (existingIdx != -1) {
      _customers[existingIdx] = finalCustomer;
    } else {
      _customers.insert(0, finalCustomer);
    }
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
      notifyListeners();
    }
  }

  Future<bool> updateCustomer(CustomerModel updated) async {
    _isLoading = true;
    notifyListeners();

    if (updated.id.isNotEmpty) {
      await _api.put('${Endpoints.customers}/${updated.id}', updated.toJson());
    }
    _isLoading = false;

    final index = _customers.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      _customers[index] = updated;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> deleteCustomer(String id) async {
    if (id.isNotEmpty) {
      await _api.delete('${Endpoints.customers}/$id');
    }
    _customers.removeWhere((c) => c.id == id);
    notifyListeners();
    return true;
  }
}
