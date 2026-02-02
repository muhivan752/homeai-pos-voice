import 'intent.dart';
import 'intent_type.dart';
import 'intent_payload.dart';
import 'dart:math';

class IntentParser {
  // Pattern: "jual [item] [qty]" - e.g., "jual kopi susu 2"
  final _sellRegex = RegExp(r'jual\s+(.+?)\s+(\d+)$', caseSensitive: false);

  Intent parse(String text) {
    final id = _genId();
    final normalized = text.trim().toLowerCase();

    // Try sell item pattern
    final sellMatch = _sellRegex.firstMatch(normalized);
    if (sellMatch != null) {
      final item = sellMatch.group(1)!.trim();
      final qty = int.parse(sellMatch.group(2)!);
      return Intent(
        id: id,
        type: IntentType.sellItem,
        payload: SellItemPayload(
          item: item,
          qty: qty,
        ),
      );
    }

    // Checkout / bayar
    if (normalized.contains('checkout') || normalized.contains('bayar')) {
      return Intent(
        id: id,
        type: IntentType.checkout,
        payload: CheckoutPayload(),
      );
    }

    return Intent(
      id: id,
      type: IntentType.unknown,
      payload: UnknownPayload(),
    );
  }

  String _genId() => DateTime.now().microsecondsSinceEpoch.toString();
}