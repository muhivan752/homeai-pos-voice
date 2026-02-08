import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/product.dart';

class ProductProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();

  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategory;
  bool _isLoading = false;
  String? _error;
  DateTime? _lastSyncedAt;

  List<Product> get products => _selectedCategory == null ? _products : _filteredProducts;
  List<Map<String, dynamic>> get categories => _categories;
  String? get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get hasProducts => _products.isNotEmpty;

  Map<String, List<Product>> get productsByCategory {
    final map = <String, List<Product>>{};
    for (final product in _products) {
      map.putIfAbsent(product.category, () => []).add(product);
    }
    return map;
  }

  Future<void> loadProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load categories
      _categories = await _db.getCategories();
      if (_categories.isEmpty) {
        _categories = [
          {'id': 'all', 'name': 'Semua', 'icon': 'grid_view'},
          {'id': 'food', 'name': 'Makanan', 'icon': 'restaurant'},
          {'id': 'drink', 'name': 'Minuman', 'icon': 'local_cafe'},
          {'id': 'snack', 'name': 'Snack', 'icon': 'cookie'},
          {'id': 'other', 'name': 'Lainnya', 'icon': 'category'},
        ];
      }

      final dbProducts = await _db.getProducts();

      if (dbProducts.isNotEmpty) {
        _products = dbProducts.map((p) => Product(
          id: p['id'] ?? p['item_code'],
          name: p['name'],
          price: (p['price'] as num).toDouble(),
          category: p['category'] ?? 'other',
          aliases: (p['aliases'] as String?)?.split(',') ?? [],
          barcode: p['barcode'],
        )).toList();

        if (dbProducts.first['synced_at'] != null) {
          _lastSyncedAt = DateTime.tryParse(dbProducts.first['synced_at']);
        }
      } else {
        // Load sample products if DB is empty
        _products = Product.sampleProducts;
      }
    } catch (e) {
      _error = e.toString();
      // Fallback to sample products
      _products = Product.sampleProducts;
    }

    _isLoading = false;
    notifyListeners();
  }

  void setCategory(String? category) {
    _selectedCategory = category;
    if (category == null || category == 'all') {
      _filteredProducts = _products;
    } else {
      _filteredProducts = _products.where((p) => p.category == category).toList();
    }
    notifyListeners();
  }

  Future<Product?> findByBarcode(String barcode) async {
    // Check in memory first
    for (final product in _products) {
      if (product.barcode == barcode) return product;
    }

    // Check in database
    final dbProduct = await _db.getProductByBarcode(barcode);
    if (dbProduct != null) {
      return Product(
        id: dbProduct['id'] ?? dbProduct['item_code'],
        name: dbProduct['name'],
        price: (dbProduct['price'] as num).toDouble(),
        category: dbProduct['category'] ?? 'other',
        aliases: (dbProduct['aliases'] as String?)?.split(',') ?? [],
        barcode: dbProduct['barcode'],
      );
    }

    return null;
  }

  Product? findProduct(String query) {
    final lowerQuery = query.toLowerCase().trim();

    // Search in loaded products first (faster)
    for (final product in _products) {
      if (product.name.toLowerCase() == lowerQuery) return product;
      for (final alias in product.aliases) {
        if (alias.toLowerCase() == lowerQuery) return product;
      }
    }

    // Fuzzy match
    for (final product in _products) {
      if (product.name.toLowerCase().contains(lowerQuery)) return product;
      for (final alias in product.aliases) {
        if (alias.toLowerCase().contains(lowerQuery)) return product;
      }
    }

    return null;
  }

  Future<void> refreshFromDb() async {
    await loadProducts();
  }
}
