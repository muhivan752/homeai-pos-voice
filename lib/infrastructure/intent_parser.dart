import '../intent/intent.dart';
import '../intent/intent_type.dart';
import '../intent/intent_payload.dart';
import 'dart:math';

class IntentParser {
  Intent parse(String text) {
    final id = _genId();
    final lower = text.toLowerCase();

    if (lower.contains('jual')) {
      final qty = _extractQty(lower);
      final item = _extractItem(lower);
      return Intent(
        id: id,
        type: IntentType.sellItem,
        payload: SellItemPayload(item: item, qty: qty),
      );
    }

    if (lower.contains('checkout') || lower.contains('bayar')) {
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

  int _extractQty(String text) {
    final match = RegExp(r'\d+').firstMatch(text);
    return match != null ? int.parse(match.group(0)!) : 1;
  }

  String _extractItem(String text) {
    // Simple extraction - remove "jual" and numbers
    return text
        .replaceAll(RegExp(r'jual|bayar|\d+'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _genId() => Random().nextInt(999999).toString().padLeft(6, '0');
}
