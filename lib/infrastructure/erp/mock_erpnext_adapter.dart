import '../../intent/intent_port.dart';
import '../../intent/intent_payload.dart';

/// Mock ERPNext adapter untuk demo/testing tanpa server.
/// Gunakan ini di entrypoint jika belum ada ERPNext server.
class MockERPNextAdapter implements IntentPort {
  final List<Map<String, dynamic>> _cart = [];

  @override
  Future<void> sellItem(SellItemPayload payload) async {
    _cart.add({
      'item': payload.item,
      'qty': payload.qty,
    });
    print('[MockERP] Item ditambahkan: ${payload.item} x${payload.qty}');
    print('[MockERP] Cart: $_cart');
  }

  @override
  Future<void> checkout() async {
    if (_cart.isEmpty) {
      print('[MockERP] Cart kosong, tidak ada yang di-checkout');
      return;
    }
    print('[MockERP] === CHECKOUT ===');
    for (final item in _cart) {
      print('[MockERP]   ${item['item']} x${item['qty']}');
    }
    print('[MockERP] === SELESAI ===');
    _cart.clear();
  }
}
