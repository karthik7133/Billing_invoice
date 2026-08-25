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
    return _products.where((p) {
      final name = p.name.toLowerCase();
      final hsn = p.hsnSac.toLowerCase();
      final desc = p.description.toLowerCase();
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || hsn.contains(q) || desc.contains(q);
    }).toList();
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
