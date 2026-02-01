import '../lib/intent/intent_port.dart';
import '../lib/intent/intent_payload.dart';

/// Mock implementation of IntentPort for unit testing.
/// Logs all operations for verification.
class MockIntentPort implements IntentPort {
  final List<String> logs = [];
  bool shouldFail = false;
  String failMessage = 'Mock error';

  void _checkFail() {
    if (shouldFail) throw MockPortError(failMessage);
  }

  // === CART OPERATIONS ===

  @override
  Future<void> addItem(AddItemPayload payload) async {
    _checkFail();
    logs.add('addItem: ${payload.item} x${payload.qty}');
  }

  @override
  Future<void> removeItem(RemoveItemPayload payload) async {
    _checkFail();
    logs.add('removeItem: ${payload.item}');
  }

  @override
  Future<void> changeQty(ChangeQtyPayload payload) async {
    _checkFail();
    logs.add('changeQty: ${payload.item} -> ${payload.newQty}');
  }

  @override
  Future<void> clearCart() async {
    _checkFail();
    logs.add('clearCart');
  }

  @override
  Future<void> undoLast() async {
    _checkFail();
    logs.add('undoLast');
  }

  // === CHECKOUT ===

  @override
  Future<void> checkout() async {
    _checkFail();
    logs.add('checkout');
  }

  // === INQUIRY ===

  @override
  Future<CartTotal> readTotal() async {
    _checkFail();
    logs.add('readTotal');
    return CartTotal(total: 50000, discount: 0, grandTotal: 50000, itemCount: 2);
  }

  @override
  Future<List<CartItem>> readCart() async {
    _checkFail();
    logs.add('readCart');
    return [
      CartItem(item: 'Kopi Susu', itemCode: 'kopi_susu', qty: 2, rate: 25000, amount: 50000),
    ];
  }

  // === TEST HELPERS ===

  void reset() {
    logs.clear();
    shouldFail = false;
    failMessage = 'Mock error';
  }
}

class MockPortError implements Exception {
  final String message;
  MockPortError(this.message);

  @override
  String toString() => message;
}
