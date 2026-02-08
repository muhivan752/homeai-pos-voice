import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../database/database_helper.dart';
import '../services/sync_service.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  final DatabaseHelper _db = DatabaseHelper();
  final SyncService _syncService = SyncService();
  final Uuid _uuid = const Uuid();

  String _lastMessage = '';
  bool _isSuccess = true;
  bool _isProcessing = false;

  List<CartItem> get items => List.unmodifiable(_items);
  String get lastMessage => _lastMessage;
  bool get isSuccess => _isSuccess;
  bool get isProcessing => _isProcessing;
  double get total => _items.fold(0, (sum, item) => sum + item.total);
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  void addItem(dynamic productOrId, [dynamic nameOrQuantity, double? price, int quantity = 1]) {
    String id;
    String itemName;
    double itemPrice;
    int itemQuantity = quantity;

    if (productOrId is Product) {
      id = productOrId.id;
      itemName = productOrId.name;
      itemPrice = productOrId.price;
      // If second param is int, it's quantity (old API compatibility)
      if (nameOrQuantity is int) {
        itemQuantity = nameOrQuantity;
      }
    } else {
      id = productOrId.toString();
      itemName = nameOrQuantity?.toString() ?? 'Unknown';
      itemPrice = price ?? 0;
    }

    final existingIndex = _items.indexWhere((item) => item.id == id);

    if (existingIndex >= 0) {
      _items[existingIndex].quantity += itemQuantity;
    } else {
      _items.add(CartItem(
        id: id,
        name: itemName,
        price: itemPrice,
        quantity: itemQuantity,
      ));
    }

    _lastMessage = 'Ditambahkan: $itemName x$itemQuantity';
    _isSuccess = true;
    notifyListeners();
  }

  void removeItem(String itemId) {
    final index = _items.indexWhere((item) => item.id == itemId);
    if (index >= 0) {
      final item = _items[index];
      _items.removeAt(index);
      _lastMessage = 'Dihapus: ${item.name}';
      _isSuccess = true;
      notifyListeners();
    }
  }

  void updateQuantity(String itemId, int quantity) {
    final index = _items.indexWhere((item) => item.id == itemId);
    if (index >= 0) {
      if (quantity <= 0) {
        removeItem(itemId);
      } else {
        _items[index].quantity = quantity;
        _lastMessage = 'Update: ${_items[index].name} x$quantity';
        _isSuccess = true;
        notifyListeners();
      }
    }
  }

  void clearCart() {
    _items.clear();
    _lastMessage = 'Keranjang dikosongkan';
    _isSuccess = true;
    notifyListeners();
  }

  /// Checkout and save transaction locally
  /// Returns transaction ID if successful
  Future<String?> checkout({
    String? customerName,
    String paymentMethod = 'Cash',
  }) async {
    return checkoutWithPayment(
      paymentMethod: paymentMethod,
      customerName: customerName,
    );
  }

  /// Checkout with full payment details
  Future<String?> checkoutWithPayment({
    required String paymentMethod,
    double? paymentAmount,
    double? changeAmount,
    String? paymentReference,
    String? cashierId,
    String? cashierName,
    String? customerName,
  }) async {
    if (_items.isEmpty) {
      _lastMessage = 'Keranjang kosong!';
      _isSuccess = false;
      notifyListeners();
      return null;
    }

    _isProcessing = true;
    notifyListeners();

    try {
      final transactionId = _uuid.v4();
      final totalAmount = total;
      final now = DateTime.now().toIso8601String();

      // Prepare transaction data
      final transaction = {
        'id': transactionId,
        'total': totalAmount,
        'payment_method': paymentMethod,
        'payment_amount': paymentAmount ?? totalAmount,
        'change_amount': changeAmount ?? 0,
        'payment_reference': paymentReference,
        'customer_name': customerName ?? 'Walk-in Customer',
        'cashier_id': cashierId,
        'cashier_name': cashierName,
        'status': 'completed',
        'sync_status': 'pending',
        'created_at': now,
      };

      // Prepare items data
      final transactionItems = _items.map((item) => {
        'transaction_id': transactionId,
        'product_id': item.id,
        'product_name': item.name,
        'quantity': item.quantity,
        'price': item.price,
        'subtotal': item.total,
      }).toList();

      // Save to local database
      await _db.insertTransaction(transaction, transactionItems);

      // Clear cart
      final itemsCount = itemCount;
      _items.clear();

      _lastMessage = 'Transaksi berhasil! Total: Rp ${_formatCurrency(totalAmount)} ($itemsCount item)';
      _isSuccess = true;
      _isProcessing = false;
      notifyListeners();

      // Trigger background sync (non-blocking)
      _syncService.syncNow();

      return transactionId;
    } catch (e) {
      _lastMessage = 'Error: ${e.toString()}';
      _isSuccess = false;
      _isProcessing = false;
      notifyListeners();
      return null;
    }
  }

  void setError(String message) {
    _lastMessage = message;
    _isSuccess = false;
    notifyListeners();
  }

  void setSuccess(String message) {
    _lastMessage = message;
    _isSuccess = true;
    notifyListeners();
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}
