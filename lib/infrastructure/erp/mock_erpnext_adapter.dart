import '../../intent/intent_port.dart';
import '../../intent/intent_payload.dart';

/// Phase 1: Mock ERPNext adapter untuk demo/testing.
/// Implements semua IntentPort methods dengan in-memory state.
class MockERPNextAdapter implements IntentPort {
  /// Current cart items
  final List<_MockCartItem> _cart = [];

  /// History untuk undo
  final List<_UndoAction> _history = [];

  // === CART OPERATIONS ===

  @override
  Future<void> addItem(AddItemPayload payload) async {
    final item = _MockCartItem(
      item: payload.item,
      itemCode: _toItemCode(payload.item),
      qty: payload.qty,
      rate: _mockPrice(payload.item),
    );
    _cart.add(item);
    _history.add(_UndoAction.add(item));
    print('[MockERP] + ${payload.item} x${payload.qty}');
  }

  @override
  Future<void> removeItem(RemoveItemPayload payload) async {
    final index = _cart.indexWhere(
      (i) => i.item.toLowerCase() == payload.item.toLowerCase(),
    );
    if (index != -1) {
      final removed = _cart.removeAt(index);
      _history.add(_UndoAction.remove(removed));
      print('[MockERP] - ${payload.item}');
    } else {
      throw MockERPError('Item "${payload.item}" tidak ada di keranjang');
    }
  }

  @override
  Future<void> changeQty(ChangeQtyPayload payload) async {
    final index = _cart.indexWhere(
      (i) => i.item.toLowerCase() == payload.item.toLowerCase(),
    );
    if (index != -1) {
      final oldItem = _cart[index];
      final newItem = _MockCartItem(
        item: oldItem.item,
        itemCode: oldItem.itemCode,
        qty: payload.newQty,
        rate: oldItem.rate,
      );
      _cart[index] = newItem;
      _history.add(_UndoAction.change(oldItem, newItem));
      print('[MockERP] ${payload.item}: qty → ${payload.newQty}');
    } else {
      throw MockERPError('Item "${payload.item}" tidak ada di keranjang');
    }
  }

  @override
  Future<void> clearCart() async {
    if (_cart.isEmpty) {
      throw MockERPError('Keranjang sudah kosong');
    }
    _history.add(_UndoAction.clear(List.from(_cart)));
    _cart.clear();
    print('[MockERP] Keranjang dikosongkan');
  }

  @override
  Future<void> undoLast() async {
    if (_history.isEmpty) {
      throw MockERPError('Tidak ada yang bisa di-undo');
    }
    final action = _history.removeLast();
    switch (action.type) {
      case _UndoType.add:
        _cart.remove(action.item);
        print('[MockERP] Undo: hapus ${action.item!.item}');
        break;
      case _UndoType.remove:
        _cart.add(action.item!);
        print('[MockERP] Undo: tambah ${action.item!.item}');
        break;
      case _UndoType.change:
        final index = _cart.indexWhere((i) => i.item == action.newItem!.item);
        if (index != -1) {
          _cart[index] = action.item!;
          print('[MockERP] Undo: ${action.item!.item} qty → ${action.item!.qty}');
        }
        break;
      case _UndoType.clear:
        _cart.addAll(action.items!);
        print('[MockERP] Undo: restore ${action.items!.length} items');
        break;
    }
  }

  // === CHECKOUT ===

  @override
  Future<void> checkout() async {
    if (_cart.isEmpty) {
      throw MockERPError('Keranjang kosong');
    }
    final total = _cart.fold<double>(0, (sum, i) => sum + i.amount);
    print('[MockERP] === CHECKOUT ===');
    for (final item in _cart) {
      print('[MockERP]   ${item.item} x${item.qty} = Rp ${item.amount.toStringAsFixed(0)}');
    }
    print('[MockERP]   TOTAL: Rp ${total.toStringAsFixed(0)}');
    print('[MockERP] === SELESAI ===');
    _cart.clear();
    _history.clear();
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

  double _mockPrice(String item) {
    // Mock pricing
    final prices = {
      'kopi susu': 25000,
      'es teh': 10000,
      'americano': 30000,
      'cappuccino': 35000,
      'latte': 35000,
    };
    return prices[item.toLowerCase()]?.toDouble() ?? 15000;
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

enum _UndoType { add, remove, change, clear }

class _UndoAction {
  final _UndoType type;
  final _MockCartItem? item;
  final _MockCartItem? newItem;
  final List<_MockCartItem>? items;

  _UndoAction._(this.type, {this.item, this.newItem, this.items});

  factory _UndoAction.add(_MockCartItem item) =>
      _UndoAction._(_UndoType.add, item: item);

  factory _UndoAction.remove(_MockCartItem item) =>
      _UndoAction._(_UndoType.remove, item: item);

  factory _UndoAction.change(_MockCartItem old, _MockCartItem newItem) =>
      _UndoAction._(_UndoType.change, item: old, newItem: newItem);

  factory _UndoAction.clear(List<_MockCartItem> items) =>
      _UndoAction._(_UndoType.clear, items: items);
}

class MockERPError implements Exception {
  final String message;
  MockERPError(this.message);

  @override
  String toString() => message;
}
