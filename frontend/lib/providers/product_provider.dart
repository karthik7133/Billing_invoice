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
  bool _isInitialized = false;

  ProductProvider() {
    _initFromCache();
  }

  Future<void> _initFromCache() async {
    if (_isInitialized) return;
    final cached = await _cache.loadProducts();
    if (cached.isNotEmpty && _products.isEmpty) {
      _products = cached;
      notifyListeners();
    }
    _isInitialized = true;
  }

  List<ProductModel> get products {
    if (_searchQuery.isEmpty) return _products;
    final q = _searchQuery.toLowerCase();
    return _products.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  /// Adds or updates an item in the catalog (called automatically when adding items in invoices)
  Future<ProductModel?> addOrUpdateItem({
    required String name,
    required double price,
    required String unit,
  }) async {
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
      await updateProduct(updated);
      return updated;
    } else {
      final newProd = ProductModel(
        id: _uuid.v4(),
        name: cleanName,
        price: price,
        unit: unit.isNotEmpty ? unit : 'Kg',
        gstRate: 0.0,
      );
      return await addProduct(newProd);
    }
  }

  /// Syncs/seeds products from existing invoices so that all items previously added
  /// are preserved in the catalog.
  Future<void> syncItemsFromInvoices(List<dynamic> invoices) async {
    await _initFromCache();
    bool hasChanges = false;
    for (final inv in invoices) {
      final items = (inv as dynamic).items as List<dynamic>?;
      if (items == null) continue;
      for (final it in items) {
        final itName = (it.name as String?)?.trim() ?? '';
        if (itName.isEmpty) continue;
        final itRate = (it.rate as num?)?.toDouble() ?? 0.0;
        final itUnit = (it.unit as String?)?.trim() ?? 'Kg';

        final existing = _products.any(
          (p) => p.name.trim().toLowerCase() == itName.toLowerCase(),
        );

        if (!existing) {
          final newProd = ProductModel(
            id: _uuid.v4(),
            name: itName,
            price: itRate,
            unit: itUnit.isNotEmpty ? itUnit : 'Kg',
            gstRate: 0.0,
          );
          _products.add(newProd);
          hasChanges = true;
        }
      }
    }

    if (hasChanges) {
      await _cache.saveProducts(_products);
      notifyListeners();
    }
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setSearchQuery(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  Future<void> fetchProducts() async {
    await _initFromCache();
    _isLoading = true;
    notifyListeners();

    final res = await _api.get(Endpoints.products);
    _isLoading = false;

    if (res.success && res.data != null && res.data['products'] != null) {
      final list = (res.data['products'] as List)
          .map((p) => ProductModel.fromJson(p as Map<String, dynamic>))
          .toList();
      _products = list;
      await _cache.saveProducts(_products);
    }
    notifyListeners();
  }

  Future<ProductModel?> addProduct(ProductModel newProduct) async {
    _isLoading = true;
    notifyListeners();

    final res = await _api.post(Endpoints.products, newProduct.toJson());
    _isLoading = false;

    ProductModel finalProduct;
    if (res.success && res.data != null && res.data['product'] != null) {
      finalProduct = ProductModel.fromJson(res.data['product']);
    } else {
      finalProduct = newProduct.copyWith(id: _uuid.v4());
    }

    _products.insert(0, finalProduct);
    await _cache.saveProducts(_products);
    notifyListeners();
    return finalProduct;
  }

  Future<bool> updateProduct(ProductModel updated) async {
    _isLoading = true;
    notifyListeners();

    if (updated.id.isNotEmpty) {
      await _api.put('${Endpoints.products}/${updated.id}', updated.toJson());
    }
    _isLoading = false;

    final index = _products.indexWhere((p) => p.id == updated.id);
    if (index != -1) {
      _products[index] = updated;
      await _cache.saveProducts(_products);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> deleteProduct(String id) async {
    if (id.isNotEmpty) {
      await _api.delete('${Endpoints.products}/$id');
    }
    _products.removeWhere((p) => p.id == id);
    await _cache.saveProducts(_products);
    notifyListeners();
    return true;
  }
}
