import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../models/product.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  String _lastMessage = '';
  bool _isSuccess = true;

  List<CartItem> get items => List.unmodifiable(_items);

  String get lastMessage => _lastMessage;
  bool get isSuccess => _isSuccess;

  double get total => _items.fold(0, (sum, item) => sum + item.total);

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  void addItem(Product product, int quantity) {
    final existingIndex = _items.indexWhere((item) => item.id == product.id);

    if (existingIndex >= 0) {
      _items[existingIndex].quantity += quantity;
    } else {
      _items.add(CartItem(
        id: product.id,
        name: product.name,
        price: product.price,
        quantity: quantity,
      ));
    }

    _lastMessage = 'Ditambahkan: ${product.name} x$quantity';
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

  bool checkout() {
    if (_items.isEmpty) {
      _lastMessage = 'Keranjang kosong!';
      _isSuccess = false;
      notifyListeners();
      return false;
    }

    final totalAmount = total;
    final itemsCount = itemCount;

    _items.clear();
    _lastMessage = 'Checkout berhasil! Total: Rp ${_formatCurrency(totalAmount)} ($itemsCount item)';
    _isSuccess = true;
    notifyListeners();
    return true;
  }

  void setError(String message) {
    _lastMessage = message;
    _isSuccess = false;
    notifyListeners();
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}
