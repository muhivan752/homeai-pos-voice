import 'intent.dart';
import 'intent_type.dart';
import 'intent_payload.dart';
import 'dart:math';

class IntentParser {
  Intent parse(String text) {
    final id = _genId();
    final lower = text.toLowerCase().trim();

    // Login: "login admin admin123"
    if (lower.startsWith('login ')) {
      final parts = lower.split(' ');
      if (parts.length >= 3) {
        return Intent(
          id: id,
          type: IntentType.login,
          payload: LoginPayload(
            username: parts[1],
            password: parts.sublist(2).join(' '),
          ),
        );
      }
    }

    // Sell: "jual kopi susu 2", "jual americano 1", "tambah latte"
    if (lower.contains('jual') || lower.contains('tambah') || lower.contains('order')) {
      final parsed = _parseSellCommand(lower);
      return Intent(
        id: id,
        type: IntentType.sellItem,
        payload: SellItemPayload(
          item: parsed.item,
          qty: parsed.qty,
        ),
      );
    }

    // Checkout: "checkout", "bayar", "bayar cash", "bayar qris"
    if (lower.contains('checkout') || lower.contains('bayar') || lower.contains('tutup')) {
      String method = 'cash';
      if (lower.contains('qris')) method = 'qris';
      if (lower.contains('transfer')) method = 'transfer';
      if (lower.contains('debit')) method = 'debit';

      return Intent(
        id: id,
        type: IntentType.checkout,
        payload: CheckoutPayload(paymentMethod: method),
      );
    }

    // Cancel: "batal", "cancel", "batal kopi susu"
    if (lower.contains('batal') || lower.contains('cancel') || lower.contains('hapus')) {
      String? item = _extractItemAfterKeyword(lower, ['batal', 'cancel', 'hapus']);
      return Intent(
        id: id,
        type: IntentType.cancelItem,
        payload: CancelItemPayload(item: item),
      );
    }

    // Stock check: "cek stok", "stok kopi susu"
    if (lower.contains('stok') || lower.contains('stock') || lower.contains('persediaan')) {
      String? item = _extractItemAfterKeyword(lower, ['stok', 'stock', 'persediaan']);
      return Intent(
        id: id,
        type: IntentType.checkStock,
        payload: CheckStockPayload(item: item),
      );
    }

    // Daily report: "laporan", "report", "rekap"
    if (lower.contains('laporan') || lower.contains('report') || lower.contains('rekap')) {
      return Intent(
        id: id,
        type: IntentType.dailyReport,
        payload: DailyReportPayload(),
      );
    }

    // Manual sync: "sync", "sinkron"
    if (lower.contains('sync') || lower.contains('sinkron')) {
      return Intent(
        id: id,
        type: IntentType.syncManual,
        payload: SyncManualPayload(),
      );
    }

    return Intent(
      id: id,
      type: IntentType.unknown,
      payload: UnknownPayload(rawText: text),
    );
  }

  _SellParsed _parseSellCommand(String text) {
    String cleaned = text
        .replaceAll('jual', '')
        .replaceAll('tambah', '')
        .replaceAll('order', '')
        .trim();

    // Extract qty (last number in text)
    final qtyMatch = RegExp(r'(\d+)').allMatches(cleaned);
    int qty = 1;
    if (qtyMatch.isNotEmpty) {
      qty = int.parse(qtyMatch.last.group(0)!);
      cleaned = cleaned.replaceAll(RegExp(r'\d+'), '').trim();
    }

    String item = cleaned.isNotEmpty ? cleaned : 'unknown';
    return _SellParsed(item: item, qty: qty);
  }

  String? _extractItemAfterKeyword(String text, List<String> keywords) {
    for (final keyword in keywords) {
      final idx = text.indexOf(keyword);
      if (idx >= 0) {
        final after = text.substring(idx + keyword.length).trim();
        if (after.isNotEmpty) return after;
      }
    }
    return null;
  }

  String _genId() =>
      '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999).toString().padLeft(4, '0')}';
}

class _SellParsed {
  final String item;
  final int qty;
  _SellParsed({required this.item, required this.qty});
}
