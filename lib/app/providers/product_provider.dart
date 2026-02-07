import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/product.dart';

class ProductProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();

  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastSyncedAt;

  List<Product> get products => _products;
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
      final dbProducts = await _db.getProducts();

      if (dbProducts.isNotEmpty) {
        _products = dbProducts.map((p) => Product(
          id: p['id'] ?? p['item_code'],
          name: p['name'],
          price: (p['price'] as num).toDouble(),
          category: p['category'] ?? 'Lainnya',
          aliases: (p['aliases'] as String?)?.split(',') ?? [],
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
