import '../../intent/intent_port.dart';
import '../../intent/intent_payload.dart';

/// Phase 1: HARDENED Mock ERPNext adapter.
/// Mensimulasikan kondisi real ERP:
/// - Item catalog (unknown item = fail)
/// - Stock constraints (bisa habis)
/// - Undo scope terbatas (HANYA add/remove)
/// - Permission errors
class MockERPNextAdapter implements IntentPort {
  /// Current cart items
  final List<_MockCartItem> _cart = [];

  /// History untuk undo - HANYA ADD/REMOVE
  final List<_UndoAction> _undoStack = [];

  /// Simulated stock (bisa dimodifikasi untuk testing)
  final Map<String, int> _stock = {
    'kopi susu': 10,
    'es teh': 5,
    'americano': 8,
    'cappuccino': 3,
    'latte': 0, // HABIS - untuk test
  };

  /// Item catalog dengan harga
  final Map<String, double> _catalog = {
    'kopi susu': 25000,
    'es teh': 10000,
    'americano': 30000,
    'cappuccino': 35000,
    'latte': 35000,
  };

  // === CART OPERATIONS ===

  @override
  Future<void> addItem(AddItemPayload payload) async {
    final itemKey = payload.item.toLowerCase();

    // 1. Check item exists in catalog
    if (!_catalog.containsKey(itemKey)) {
      throw MockERPError('Item "${payload.item}" tidak ada di sistem.');
    }

    // 2. Check stock available
    final stock = _stock[itemKey] ?? 0;
    if (stock <= 0) {
      throw MockERPError('Stok ${payload.item} habis.');
    }
    if (stock < payload.qty) {
      throw MockERPError(
        'Stok ${payload.item} tidak cukup. Sisa $stock.',
      );
    }

    // 3. Add to cart
    final item = _MockCartItem(
      item: payload.item,
      itemCode: _toItemCode(payload.item),
      qty: payload.qty,
      rate: _catalog[itemKey]!,
    );
    _cart.add(item);

    // 4. Reduce stock
    _stock[itemKey] = stock - payload.qty;

    // 5. Record for undo (ALLOWED)
    _undoStack.add(_UndoAction.add(item));

    print('[MockERP] + ${payload.item} x${payload.qty} (sisa stok: ${_stock[itemKey]})');
  }

  @override
  Future<void> removeItem(RemoveItemPayload payload) async {
    final itemKey = payload.item.toLowerCase();

    final index = _cart.indexWhere(
      (i) => i.item.toLowerCase() == itemKey,
    );

    if (index == -1) {
      throw MockERPError('Item "${payload.item}" tidak ada di keranjang.');
    }

    final removed = _cart.removeAt(index);

    // Restore stock
    _stock[itemKey] = (_stock[itemKey] ?? 0) + removed.qty;

    // Record for undo (ALLOWED)
    _undoStack.add(_UndoAction.remove(removed));

    print('[MockERP] - ${payload.item} (stok dikembalikan: ${removed.qty})');
  }

  @override
  Future<void> changeQty(ChangeQtyPayload payload) async {
    final itemKey = payload.item.toLowerCase();

    final index = _cart.indexWhere(
      (i) => i.item.toLowerCase() == itemKey,
    );

    if (index == -1) {
      throw MockERPError('Item "${payload.item}" tidak ada di keranjang.');
    }

    final oldItem = _cart[index];
    final qtyDiff = payload.newQty - oldItem.qty;

    // Check stock if increasing qty
    if (qtyDiff > 0) {
      final stock = _stock[itemKey] ?? 0;
      if (stock < qtyDiff) {
        throw MockERPError(
          'Stok ${payload.item} tidak cukup. Sisa $stock.',
        );
      }
      _stock[itemKey] = stock - qtyDiff;
    } else {
      // Restore stock if decreasing
      _stock[itemKey] = (_stock[itemKey] ?? 0) - qtyDiff;
    }

    // Update cart
    _cart[index] = _MockCartItem(
      item: oldItem.item,
      itemCode: oldItem.itemCode,
      qty: payload.newQty,
      rate: oldItem.rate,
    );

    // ⚠️ changeQty TIDAK masuk undo stack
    // Clear undo stack karena state sudah berubah
    _undoStack.clear();

    print('[MockERP] ${payload.item}: qty ${oldItem.qty} → ${payload.newQty}');
  }

  @override
  Future<void> clearCart() async {
    if (_cart.isEmpty) {
      throw MockERPError('Keranjang sudah kosong.');
    }

    // Restore all stock
    for (final item in _cart) {
      final itemKey = item.item.toLowerCase();
      _stock[itemKey] = (_stock[itemKey] ?? 0) + item.qty;
    }

    _cart.clear();

    // ⚠️ clearCart TIDAK masuk undo stack
    // Clear undo stack - tidak bisa di-undo
    _undoStack.clear();

    print('[MockERP] Keranjang dikosongkan. Stok dikembalikan.');
  }

  @override
  Future<void> undoLast() async {
    // ⚠️ UNDO HANYA UNTUK ADD/REMOVE
    if (_undoStack.isEmpty) {
      throw MockERPError(
        'Tidak ada yang bisa di-undo. Undo hanya untuk tambah/hapus item terakhir.',
      );
    }

    final action = _undoStack.removeLast();

    switch (action.type) {
      case _UndoType.add:
        // Undo add = remove item, restore stock
        _cart.remove(action.item);
        final itemKey = action.item!.item.toLowerCase();
        _stock[itemKey] = (_stock[itemKey] ?? 0) + action.item!.qty;
        print('[MockERP] Undo: hapus ${action.item!.item}');
        break;

      case _UndoType.remove:
        // Undo remove = add item back, reduce stock
        _cart.add(action.item!);
        final itemKey = action.item!.item.toLowerCase();
        _stock[itemKey] = (_stock[itemKey] ?? 0) - action.item!.qty;
        print('[MockERP] Undo: kembalikan ${action.item!.item}');
        break;
    }
  }

  // === CHECKOUT ===

  @override
  Future<void> checkout() async {
    if (_cart.isEmpty) {
      throw MockERPError('Tidak ada item untuk checkout. Tambah item dulu.');
    }

    final total = _cart.fold<double>(0, (sum, i) => sum + i.amount);

    print('[MockERP] === CHECKOUT ===');
    for (final item in _cart) {
      print('[MockERP]   ${item.item} x${item.qty} = Rp ${item.amount.toStringAsFixed(0)}');
    }
    print('[MockERP]   TOTAL: Rp ${total.toStringAsFixed(0)}');
    print('[MockERP] === INVOICE SUBMITTED ===');

    // Clear state after checkout
    _cart.clear();
    _undoStack.clear();
  }

  // === INQUIRY ===

  @override
  Future<CartTotal> readTotal() async {
    final total = _cart.fold<double>(0, (sum, i) => sum + i.amount);
    return CartTotal(
      total: total,
      discount: 0,
      grandTotal: total,
      itemCount: _cart.length,
    );
  }

  @override
  Future<List<CartItem>> readCart() async {
    return _cart
        .map((i) => CartItem(
              item: i.item,
              itemCode: i.itemCode,
              qty: i.qty,
              rate: i.rate,
              amount: i.amount,
            ))
        .toList();
  }

  // === HELPERS ===

  String _toItemCode(String item) {
    return item.toLowerCase().replaceAll(' ', '_');
  }

  /// For testing: reset stock
  void resetStock() {
    _stock['kopi susu'] = 10;
    _stock['es teh'] = 5;
    _stock['americano'] = 8;
    _stock['cappuccino'] = 3;
    _stock['latte'] = 0;
  }

  /// For testing: set specific stock
  void setStock(String item, int qty) {
    _stock[item.toLowerCase()] = qty;
  }
}

class _MockCartItem {
  final String item;
  final String itemCode;
  final int qty;
  final double rate;

  _MockCartItem({
    required this.item,
    required this.itemCode,
    required this.qty,
    required this.rate,
  });

  double get amount => rate * qty;
}

/// Undo HANYA untuk add/remove
enum _UndoType { add, remove }

class _UndoAction {
  final _UndoType type;
  final _MockCartItem? item;

  _UndoAction._(this.type, {this.item});

  factory _UndoAction.add(_MockCartItem item) =>
      _UndoAction._(_UndoType.add, item: item);

  factory _UndoAction.remove(_MockCartItem item) =>
      _UndoAction._(_UndoType.remove, item: item);
}

class MockERPError implements Exception {
  final String message;
  MockERPError(this.message);

  @override
  String toString() => message;
}
