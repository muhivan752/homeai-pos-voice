import 'intent.dart';
import 'intent_type.dart';
import 'intent_payload.dart';
import 'dart:math';

class IntentParser {
  Intent parse(String text) {
    final id = _genId();

    if (text.contains('jual')) {
      return Intent(
        id: id,
        type: IntentType.sellItem,
        payload: SellItemPayload(
          item: 'kopi susu', // sementara hardcode
          qty: 2,
        ),
      );
    }

    if (text.contains('checkout') || text.contains('bayar')) {
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

  String _genId() => Random().nextInt(999999).toString();
}