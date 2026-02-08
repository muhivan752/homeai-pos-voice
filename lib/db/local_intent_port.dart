import '../intent/intent_port.dart';
import '../intent/intent_payload.dart';
import 'local_db.dart';

class LocalIntentPort implements IntentPort {
  final LocalDB db;

  LocalIntentPort(this.db);

  @override
  Future<void> sellItem(SellItemPayload payload) async {
    db.addToCart(item: payload.item, qty: payload.qty);
    print('[POS] Tambah ke keranjang: ${payload.item} x${payload.qty}');
  }

  @override
  Future<void> checkout(CheckoutPayload payload) async {
    if (db.cart.isEmpty) {
      throw Exception('Keranjang kosong, tidak bisa checkout');
    }

    // Simpan transaksi checkout ke LocalDB
    final checkoutId = DateTime.now().millisecondsSinceEpoch.toString();
    await db.addTransaction(
      id: 'checkout-$checkoutId',
      type: 'checkout',
      data: {
        'items': db.cart.toList(),
        'paymentMethod': payload.paymentMethod,
        'totalItems': db.cart.fold<int>(0, (sum, e) => sum + (e['qty'] as int)),
      },
    );

    print('[POS] Checkout ${db.cart.length} item via ${payload.paymentMethod}');
    db.clearCart();
  }

  @override
  Future<void> cancelItem(CancelItemPayload payload) async {
    final removed = db.removeFromCart(item: payload.item);
    if (!removed) {
      throw Exception('Item "${payload.item ?? "terakhir"}" tidak ditemukan di keranjang');
    }
    print('[POS] Batal item: ${payload.item ?? "terakhir"}');
  }

  @override
  Future<Map<String, int>> checkStock(CheckStockPayload payload) async {
    return db.getStock(item: payload.item);
  }

  @override
  Future<Map<String, dynamic>> dailyReport() async {
    return db.getDailyReport();
  }
}
