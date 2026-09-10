import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/customer_model.dart';
import '../models/product_model.dart';
import '../models/invoice_model.dart';
import '../models/business_model.dart';
import '../models/user_model.dart';

/// Manages local persistent offline storage so the app renders INSTANTLY (0ms)
/// on cold-starts without waiting for Render's 30-50s wake-up delay.
class LocalCacheService {
  static final LocalCacheService _instance = LocalCacheService._internal();
  factory LocalCacheService() => _instance;
  LocalCacheService._internal();

  static const _keyCustomers = 'cached_customers_v1';
  static const _keyProducts = 'cached_products_v1';
  static const _keyInvoices = 'cached_invoices_v1';
  static const _keyBusiness = 'cached_business_v1';
  static const _keyUser = 'cached_user_v1';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Key scoped to company — appends companyId for isolation; empty = legacy global key
  String _customerKey(String companyId) =>
      companyId.isNotEmpty ? '${_keyCustomers}_$companyId' : _keyCustomers;

  Future<void> saveCustomers(List<CustomerModel> customers, {String companyId = ''}) async {
    try {
      await init();
      final data = json.encode(customers.map((c) => c.toJson()).toList());
      await _prefs?.setString(_customerKey(companyId), data);
    } catch (e) {
      debugPrint('[LocalCache] Error saving customers: $e');
    }
  }

  Future<List<CustomerModel>> loadCustomers({String companyId = ''}) async {
    try {
      await init();
      String? raw = _prefs?.getString(_customerKey(companyId));
      if ((raw == null || raw.isEmpty) && companyId.isNotEmpty) {
        raw = _prefs?.getString(_keyCustomers);
      }
      if (raw == null || raw.isEmpty) return [];
      final list = json.decode(raw) as List<dynamic>;
      return list.map((c) => CustomerModel.fromJson(c as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[LocalCache] Error loading customers: $e');
      return [];
    }
  }

  /// Loads all customers across all company scopes and legacy cache
  Future<List<CustomerModel>> loadAllCustomers() async {
    try {
      await init();
      final keys = _prefs?.getKeys() ?? <String>{};
      final customerKeys = keys.where((k) => k.startsWith(_keyCustomers)).toSet();
      if (_prefs?.containsKey(_keyCustomers) == true) {
        customerKeys.add(_keyCustomers);
      }
      final Map<String, CustomerModel> byId = {};
      for (final k in customerKeys) {
        final raw = _prefs?.getString(k);
        if (raw != null && raw.isNotEmpty) {
          try {
            final list = json.decode(raw) as List<dynamic>;
            for (final item in list) {
              final cust = CustomerModel.fromJson(item as Map<String, dynamic>);
              final key = cust.id.isNotEmpty ? cust.id : cust.name.trim().toLowerCase();
              byId[key] = cust;
            }
          } catch (_) {}
        }
      }
      return byId.values.toList();
    } catch (e) {
      debugPrint('[LocalCache] Error loading all customers: $e');
      return [];
    }
  }

  // ─── Products ──────────────────────────────────────────────────────────────
  Future<void> saveProducts(List<ProductModel> products) async {
    try {
      await init();
      final data = json.encode(products.map((p) => p.toJson()).toList());
      await _prefs?.setString(_keyProducts, data);
    } catch (e) {
      debugPrint('[LocalCache] Error saving products: $e');
    }
  }

  Future<List<ProductModel>> loadProducts() async {
    try {
      await init();
      final raw = _prefs?.getString(_keyProducts);
      if (raw == null || raw.isEmpty) return [];
      final list = json.decode(raw) as List<dynamic>;
      return list.map((p) => ProductModel.fromJson(p as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[LocalCache] Error loading products: $e');
      return [];
    }
  }

  // ─── Invoices ──────────────────────────────────────────────────────────────
  /// Key scoped to company — appends companyId for isolation; empty = legacy global key
  String _invoiceKey(String companyId) =>
      companyId.isNotEmpty ? '${_keyInvoices}_$companyId' : _keyInvoices;

  Future<void> saveInvoices(List<InvoiceModel> invoices, {String companyId = ''}) async {
    try {
      await init();
      final data = json.encode(invoices.map((i) => i.toJson()).toList());
      await _prefs?.setString(_invoiceKey(companyId), data);
    } catch (e) {
      debugPrint('[LocalCache] Error saving invoices: $e');
    }
  }

  Future<List<InvoiceModel>> loadInvoices({String companyId = ''}) async {
    try {
      await init();
      String? raw = _prefs?.getString(_invoiceKey(companyId));
      if ((raw == null || raw.isEmpty) && companyId.isNotEmpty) {
        raw = _prefs?.getString(_keyInvoices);
      }
      if (raw == null || raw.isEmpty) return [];
      final list = json.decode(raw) as List<dynamic>;
      return list.map((i) => InvoiceModel.fromJson(i as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[LocalCache] Error loading invoices: $e');
      return [];
    }
  }

  /// Loads all invoices across all company scopes and legacy cache
  Future<List<InvoiceModel>> loadAllInvoices() async {
    try {
      await init();
      final keys = _prefs?.getKeys() ?? <String>{};
      final invoiceKeys = keys.where((k) => k.startsWith(_keyInvoices)).toSet();
      if (_prefs?.containsKey(_keyInvoices) == true) {
        invoiceKeys.add(_keyInvoices);
      }
      final Map<String, InvoiceModel> byId = {};
      for (final k in invoiceKeys) {
        final raw = _prefs?.getString(k);
        if (raw != null && raw.isNotEmpty) {
          try {
            final list = json.decode(raw) as List<dynamic>;
            for (final item in list) {
              final inv = InvoiceModel.fromJson(item as Map<String, dynamic>);
              final key = inv.id.isNotEmpty ? inv.id : '${inv.invoiceNumber}_${inv.customerSnapshot.name}';
              byId[key] = inv;
            }
          } catch (_) {}
        }
      }
      return byId.values.toList();
    } catch (e) {
      debugPrint('[LocalCache] Error loading all invoices: $e');
      return [];
    }
  }

  // ─── Business Profile & Multi-Companies ────────────────────────────────────
  static const _keyCompanies = 'cached_companies_v1';
  static const _keyActiveCompanyId = 'active_company_id_v1';

  Future<void> saveBusiness(BusinessModel business) async {
    try {
      await init();
      final data = json.encode(business.toJson());
      await _prefs?.setString(_keyBusiness, data);
    } catch (e) {
      debugPrint('[LocalCache] Error saving business: $e');
    }
  }

  Future<BusinessModel?> loadBusiness() async {
    try {
      await init();
      final raw = _prefs?.getString(_keyBusiness);
      if (raw == null || raw.isEmpty) return null;
      final map = json.decode(raw) as Map<String, dynamic>;
      return BusinessModel.fromJson(map);
    } catch (e) {
      debugPrint('[LocalCache] Error loading business: $e');
      return null;
    }
  }

  Future<void> saveCompanies(List<BusinessModel> companies) async {
    try {
      await init();
      final data = json.encode(companies.map((c) => c.toJson()).toList());
      await _prefs?.setString(_keyCompanies, data);
    } catch (e) {
      debugPrint('[LocalCache] Error saving companies: $e');
    }
  }

  Future<List<BusinessModel>> loadCompanies() async {
    try {
      await init();
      final raw = _prefs?.getString(_keyCompanies);
      if (raw == null || raw.isEmpty) return [];
      final list = json.decode(raw) as List<dynamic>;
      return list.map((c) => BusinessModel.fromJson(c as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[LocalCache] Error loading companies: $e');
      return [];
    }
  }

  Future<void> saveActiveCompanyId(String id) async {
    try {
      await init();
      await _prefs?.setString(_keyActiveCompanyId, id);
    } catch (e) {
      debugPrint('[LocalCache] Error saving active company id: $e');
    }
  }

  Future<String?> loadActiveCompanyId() async {
    try {
      await init();
      return _prefs?.getString(_keyActiveCompanyId);
    } catch (e) {
      debugPrint('[LocalCache] Error loading active company id: $e');
      return null;
    }
  }

  // ─── User Profile ──────────────────────────────────────────────────────────
  Future<void> saveUser(UserModel user) async {
    try {
      await init();
      final data = json.encode(user.toJson());
      await _prefs?.setString(_keyUser, data);
    } catch (e) {
      debugPrint('[LocalCache] Error saving user: $e');
    }
  }

  Future<UserModel?> loadUser() async {
    try {
      await init();
      final raw = _prefs?.getString(_keyUser);
      if (raw == null || raw.isEmpty) return null;
      final map = json.decode(raw) as Map<String, dynamic>;
      return UserModel.fromJson(map);
    } catch (e) {
      debugPrint('[LocalCache] Error loading user: $e');
      return null;
    }
  }

  // ─── Clear All Cache ───────────────────────────────────────────────────────
  Future<void> clearAll() async {
    try {
      await init();
      await _prefs?.remove(_keyCustomers);
      await _prefs?.remove(_keyProducts);
      await _prefs?.remove(_keyInvoices);
      await _prefs?.remove(_keyBusiness);
      await _prefs?.remove(_keyUser);
    } catch (e) {
      debugPrint('[LocalCache] Error clearing cache: $e');
    }
  }
}
