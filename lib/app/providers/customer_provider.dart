import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/customer.dart';

/// Manages customer recognition and memory.
///
/// This is the core of "POS yang kenal pelanggan" — remembering
/// who customers are and what they usually order.
class CustomerProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();

  Customer? _activeCustomer;
  List<FavoriteItem> _favorites = [];
  bool _isLoading = false;

  /// The currently recognized customer (null = anonymous/walk-in).
  Customer? get activeCustomer => _activeCustomer;

  /// Active customer's favorite items ("yang biasa").
  List<FavoriteItem> get favorites => _favorites;

  /// Whether the customer has a "biasa" (ordered same item 2+ times).
  bool get hasBiasa => _favorites.isNotEmpty;

  /// The top favorite item — "yang biasa".
  FavoriteItem? get yangBiasa => _favorites.isNotEmpty ? _favorites.first : null;

  bool get isLoading => _isLoading;

  /// Whether there's an active customer session.
  bool get hasCustomer => _activeCustomer != null;

  /// The active customer's name.
  String? get customerName => _activeCustomer?.name;

  /// Look up a customer by name. Returns found customer or null.
  /// If found, automatically sets as active customer.
  Future<Customer?> recognizeByName(String name) async {
    _isLoading = true;
    notifyListeners();

    try {
      final results = await _db.findCustomersByName(name);
      if (results.isNotEmpty) {
        final customer = Customer.fromMap(results.first);
        await _setActiveCustomer(customer);
        return customer;
      }
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Register a new customer and set as active.
  Future<Customer> registerCustomer(String name, {String? phone}) async {
    final customer = Customer(
      id: const Uuid().v4(),
      name: name,
      phone: phone,
      visitCount: 0,
    );

    await _db.insertCustomer(customer.toMap());
    await _setActiveCustomer(customer);
    return customer;
  }

  /// Set active customer and load their favorites.
  Future<void> _setActiveCustomer(Customer customer) async {
    _activeCustomer = customer;
    await _loadFavorites(customer.id);
    notifyListeners();
  }

  /// Load customer's favorite items from order history.
  Future<void> _loadFavorites(String customerId) async {
    final rows = await _db.getCustomerFavorites(customerId);
    _favorites = rows
        .where((r) => (r['order_count'] as int) >= 2)
        .map((r) => FavoriteItem(
              productId: r['product_id'] as String,
              productName: r['product_name'] as String,
              orderCount: r['order_count'] as int,
              totalQuantity: r['total_quantity'] as int,
            ))
        .toList();
  }

  /// Record a visit after checkout. Links transaction to customer.
  Future<void> recordVisit(String transactionId) async {
    if (_activeCustomer == null) return;

    final db = await _db.database;
    await db.update(
      'transactions',
      {'customer_id': _activeCustomer!.id},
      where: 'id = ?',
      whereArgs: [transactionId],
    );

    await _db.recordCustomerVisit(_activeCustomer!.id);
    _activeCustomer!.visitCount++;
    _activeCustomer!.lastVisitAt = DateTime.now();
    notifyListeners();
  }

  /// Clear active customer (after session ends or manually).
  void clearCustomer() {
    _activeCustomer = null;
    _favorites = [];
    notifyListeners();
  }
}
