import 'intent_port.dart';
import 'intent_payload.dart';

class MockIntentPort implements IntentPort {
  final List<Map<String, dynamic>> _cart = [];

  @override
  Future<void> sellItem(SellItemPayload payload) async {
    _cart.add({'item': payload.item, 'qty': payload.qty});
    print('[MOCK] sell ${payload.item} x${payload.qty}');
  }

  @override
  Future<void> checkout(CheckoutPayload payload) async {
    print('[MOCK] checkout via ${payload.paymentMethod}, items: $_cart');
    _cart.clear();
  }

  @override
  Future<void> cancelItem(CancelItemPayload payload) async {
    if (payload.item != null) {
      _cart.removeWhere((e) => e['item'] == payload.item);
    } else if (_cart.isNotEmpty) {
      _cart.removeLast();
    }
    print('[MOCK] cancel item: ${payload.item ?? "last"}');
  }

  @override
  Future<Map<String, int>> checkStock(CheckStockPayload payload) async {
    final allStock = {
      'kopi susu': 50,
      'americano': 30,
      'latte': 25,
      'matcha': 15,
      'croissant': 10,
    };

    if (payload.item != null) {
      final qty = allStock[payload.item];
      if (qty != null) return {payload.item!: qty};
      return {};
    }
    return allStock;
  }

  @override
  Future<Map<String, dynamic>> dailyReport() async {
    return {
      'totalTransactions': 42,
      'totalSales': 2150000,
      'topItem': 'kopi susu',
    };
  }
}
