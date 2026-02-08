import 'intent.dart';
import 'intent_type.dart';
import 'intent_payload.dart';
import 'intent_port.dart';

class IntentExecutor {
  final IntentPort port;

  IntentExecutor(this.port);

  Future<String> execute(Intent intent) async {
    switch (intent.type) {
      case IntentType.sellItem:
        final payload = intent.payload as SellItemPayload;
        await port.sellItem(payload);
        return 'Berhasil tambah ${payload.item} x${payload.qty}';

      case IntentType.checkout:
        final payload = intent.payload as CheckoutPayload;
        await port.checkout(payload);
        return 'Checkout berhasil (${payload.paymentMethod})';

      case IntentType.cancelItem:
        final payload = intent.payload as CancelItemPayload;
        await port.cancelItem(payload);
        return 'Item ${payload.item ?? "terakhir"} dibatalkan';

      case IntentType.checkStock:
        final payload = intent.payload as CheckStockPayload;
        final stock = await port.checkStock(payload);
        if (stock.isEmpty) return 'Data stok tidak tersedia';
        final lines = stock.entries.map((e) => '  ${e.key}: ${e.value}').join('\n');
        return 'Stok saat ini:\n$lines';

      case IntentType.dailyReport:
        final report = await port.dailyReport();
        return 'Laporan hari ini:\n'
            '  Total transaksi: ${report['totalTransactions'] ?? 0}\n'
            '  Total penjualan: Rp ${report['totalSales'] ?? 0}';

      case IntentType.syncManual:
      case IntentType.login:
      case IntentType.unknown:
        return '[WARN] Intent ${intent.type} tidak ditangani executor';
    }
  }
}
