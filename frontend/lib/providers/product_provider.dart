import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/product_model.dart';
import '../core/api/api_client.dart';
import '../core/api/endpoints.dart';
import '../services/local_cache_service.dart';

class ProductProvider with ChangeNotifier {
  final ApiClient _api = ApiClient();
  final LocalCacheService _cache = LocalCacheService();
  final _uuid = const Uuid();

  List<ProductModel> _products = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  bool _cacheLoaded = false;

  ProductProvider() {
    _loadCache();
  }

  Future<void> _loadCache() async {
    if (_cacheLoaded) return;
    _cacheLoaded = true;
    try {
      final cached = await _cache.loadProducts();
      if (cached.isNotEmpty) {
        final existingNames = _products.map((p) => p.name.trim().toLowerCase()).toSet();
        for (final c in cached) {
          if (!existingNames.contains(c.name.trim().toLowerCase())) {
            _products.add(c);
            existingNames.add(c.name.trim().toLowerCase());
          }
        }
        notifyListeners();
      }

      // Automatically discover and extract items from ALL cached invoices across companies
      final allInvoices = await _cache.loadAllInvoices();
      if (allInvoices.isNotEmpty) {
        await _extractItemsFromInvoiceList(allInvoices);
      }
    } catch (_) {}
  }

  List<ProductModel> get products {
    if (_searchQuery.isEmpty) return List.unmodifiable(_products);
    final q = _searchQuery.toLowerCase();
    return _products.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setSearchQuery(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  /// Fetch products from server and MERGE with local catalog.
  /// Never wipes locally-added items that haven't been pushed yet.
  Future<void> fetchProducts() async {
    // Make sure cache and invoice items are loaded first
    await _loadCache();

    if (_api.token != null && _api.token!.isNotEmpty) {
      _isLoading = true;
      notifyListeners();

      try {
        final res = await _api.get(Endpoints.products);
        _isLoading = false;

        if (res.success && res.data != null && res.data['products'] != null) {
        final serverList = (res.data['products'] as List)
            .map((p) => ProductModel.fromJson(p as Map<String, dynamic>))
            .toList();

        // Build a name-based map from server items
        final serverByName = <String, ProductModel>{};
        for (final p in serverList) {
          serverByName[p.name.trim().toLowerCase()] = p;
        }

        // Merge: start with server items, then add any local-only items
        final merged = List<ProductModel>.from(serverList);
        final mergedNames = serverByName.keys.toSet();

        for (final local in _products) {
          final key = local.name.trim().toLowerCase();
          if (!mergedNames.contains(key)) {
            merged.add(local);
            mergedNames.add(key);
          }
        }

        _products = merged;
        await _cache.saveProducts(_products);
      }
    } catch (_) {
      _isLoading = false;
    }
  }

    // Always re-ensure any invoice items are preserved in the catalog
    try {
      final allInvoices = await _cache.loadAllInvoices();
      if (allInvoices.isNotEmpty) {
        await _extractItemsFromInvoiceList(allInvoices);
      }
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  /// Syncs items from existing invoices into the catalog.
  /// Each new item is added locally AND posted to the server.
  Future<void> syncItemsFromInvoices([List<dynamic>? invoices]) async {
    await _loadCache();

    List<dynamic> list = invoices ?? [];
    if (list.isEmpty) {
      list = await _cache.loadAllInvoices();
    }
    if (list.isEmpty) return;

    await _extractItemsFromInvoiceList(list);
  }

  Future<void> _extractItemsFromInvoiceList(List<dynamic> invoices) async {
    final existingNames = _products.map((p) => p.name.trim().toLowerCase()).toSet();
    bool addedAny = false;

    for (final inv in invoices) {
      final items = (inv as dynamic).items as List<dynamic>?;
      if (items == null) continue;
      for (final it in items) {
        final itName = (it.name as String?)?.trim() ?? '';
        if (itName.isEmpty) continue;
        final key = itName.toLowerCase();
        if (existingNames.contains(key)) continue;

        final itRate = (it.rate as num?)?.toDouble() ?? 0.0;
        final itUnit = (it.unit as String?)?.trim() ?? 'Kg';

        final localProd = ProductModel(
          id: _uuid.v4(),
          name: itName,
          price: itRate,
          unit: itUnit.isNotEmpty ? itUnit : 'Kg',
          gstRate: 0.0,
        );
        _products.add(localProd);
        existingNames.add(key);
        addedAny = true;
      }
    }

    if (addedAny) {
      await _cache.saveProducts(_products);
      notifyListeners();
    }
  }

  /// Silently pushes a product to the server, updates the local id with server id if successful.
  Future<void> _pushToServer(ProductModel product) async {
    if (_api.token == null || _api.token!.isEmpty) return;
    try {
      final res = await _api.post(Endpoints.products, {
        'name': product.name,
        'price': product.price,
        'unit': product.unit,
        'gstRate': product.gstRate,
        'description': product.description,
        'hsnSac': product.hsnSac,
        'itemType': product.itemType,
      });

      if (res.success && res.data != null && res.data['product'] != null) {
        final serverProd = ProductModel.fromJson(res.data['product']);
        // Replace local UUID entry with server entry
        final idx = _products.indexWhere((p) => p.id == product.id);
        if (idx != -1) {
          _products[idx] = serverProd;
          await _cache.saveProducts(_products);
          notifyListeners();
        }
      }
    } catch (_) {
      // Silent fail — item is still in local catalog
    }
  }

  /// Adds or updates a catalog item (called when saving invoice items).
  Future<ProductModel?> addOrUpdateItem({
    required String name,
    required double price,
    required String unit,
  }) async {
    await _loadCache();
    final cleanName = name.trim();
    if (cleanName.isEmpty) return null;

    final existingIndex = _products.indexWhere(
      (p) => p.name.trim().toLowerCase() == cleanName.toLowerCase(),
    );

    if (existingIndex != -1) {
      final existing = _products[existingIndex];
      final updated = existing.copyWith(
        price: price > 0 ? price : existing.price,
        unit: unit.isNotEmpty ? unit : existing.unit,
      );
      _products[existingIndex] = updated;
      await _cache.saveProducts(_products);
      notifyListeners();
      // Also sync to server
      if (updated.id.isNotEmpty) {
        _api.put('${Endpoints.products}/${updated.id}', {
          'name': updated.name,
          'price': updated.price,
          'unit': updated.unit,
          'gstRate': updated.gstRate,
        }).catchError((_) => ApiResponse(success: false));
      }
      return updated;
    } else {
      // Add locally immediately
      final localProd = ProductModel(
        id: _uuid.v4(),
        name: cleanName,
        price: price,
        unit: unit.isNotEmpty ? unit : 'Kg',
        gstRate: 0.0,
      );
      _products.insert(0, localProd);
      await _cache.saveProducts(_products);
      notifyListeners();
      // Push to server
      _pushToServer(localProd);
      return localProd;
    }
  }

  Future<ProductModel?> addProduct(ProductModel newProduct) async {
    await _loadCache();
    _isLoading = true;
    notifyListeners();

    // Add locally first
    _products.insert(0, newProduct);
    await _cache.saveProducts(_products);
    _isLoading = false;
    notifyListeners();

    // Push to server and update id
    _pushToServer(newProduct);
    return newProduct;
  }

  Future<bool> updateProduct(ProductModel updated) async {
    final index = _products.indexWhere((p) => p.id == updated.id);
    if (index != -1) {
      _products[index] = updated;
      await _cache.saveProducts(_products);
      notifyListeners();

      if (updated.id.isNotEmpty) {
        _api
            .put('${Endpoints.products}/${updated.id}', updated.toJson())
            .catchError((_) => ApiResponse(success: false));
      }
      return true;
    }
    return false;
  }

  Future<bool> deleteProduct(String id) async {
    _products.removeWhere((p) => p.id == id);
    await _cache.saveProducts(_products);
    notifyListeners();

    if (id.isNotEmpty) {
      _api.delete('${Endpoints.products}/$id').catchError((_) => ApiResponse(success: false));
    }
    return true;
  }
}
