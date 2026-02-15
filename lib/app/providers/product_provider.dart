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

  List<Product> get products => _selectedCategory == null || _selectedCategory == 'all' ? _products : _filteredProducts;
  List<Product> get allProducts => _products;
  List<Map<String, dynamic>> get categories => _categories;
  String? get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  String? get error => _error;
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

      var dbProducts = await _db.getProducts();

      // Seed default products on first launch
      if (dbProducts.isEmpty) {
        await _seedDefaultProducts();
        dbProducts = await _db.getProducts();
      }

      if (dbProducts.isNotEmpty) {
        _products = dbProducts.map((p) => Product.fromMap(p)).toList();
      } else {
        _products = Product.sampleProducts;
      }

      // Keep static sampleProducts in sync — parser and voice use this
      Product.sampleProducts = List.from(_products);
    } catch (e) {
      _error = e.toString();
      _products = Product.sampleProducts;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Seed default products into SQLite on first launch.
  Future<void> _seedDefaultProducts() async {
    final batch = Product.sampleProducts.map((p) => p.toMap()).toList();
    await _db.insertProducts(batch);
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

  // ============ CRUD ============

  /// Add a new product.
  Future<void> addProduct(Product product) async {
    await _db.insertProduct(product.toMap());
    await loadProducts();
  }

  /// Update an existing product.
  Future<void> updateProduct(Product product) async {
    await _db.updateProduct(product.id, {
      'name': product.name,
      'price': product.price,
      'category': product.category,
      'aliases': product.aliases.join(','),
      'barcode': product.barcode,
      'stock': product.stock,
    });
    await loadProducts();
  }

  /// Soft-delete a product (set is_active = 0).
  Future<void> deleteProduct(String id) async {
    await _db.deleteProduct(id);
    await loadProducts();
  }

  // ============ STOCK ============

  /// Deduct stock after checkout. Reloads products to update UI.
  Future<void> deductStock(List<Map<String, dynamic>> items) async {
    await _db.deductStock(items);
    await loadProducts();
  }

  /// Update stock for a single product.
  Future<void> updateStock(String productId, int newStock) async {
    await _db.updateStock(productId, newStock);
    await loadProducts();
  }

  /// Get products with low stock.
  Future<List<Product>> getLowStockProducts({int threshold = 5}) async {
    final rows = await _db.getLowStockProducts(threshold: threshold);
    return rows.map((r) => Product.fromMap(r)).toList();
  }

  /// Check if a product has enough stock for the requested quantity.
  /// Returns true if stock is unlimited (-1) or sufficient.
  bool hasEnoughStock(String productId, int requestedQty) {
    final product = _products.where((p) => p.id == productId).firstOrNull;
    if (product == null) return false;
    if (!product.isStockTracked) return true; // unlimited
    return product.stock >= requestedQty;
  }

  /// Get current stock for a product. Returns -1 if not tracked.
  int getStock(String productId) {
    final product = _products.where((p) => p.id == productId).firstOrNull;
    return product?.stock ?? -1;
  }

  // ============ SEARCH ============

  Future<Product?> findByBarcode(String barcode) async {
    // Check in memory first
    for (final product in _products) {
      if (product.barcode == barcode) return product;
    }

    // Check in database
    final dbProduct = await _db.getProductByBarcode(barcode);
    if (dbProduct != null) {
      return Product.fromMap(dbProduct);
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
