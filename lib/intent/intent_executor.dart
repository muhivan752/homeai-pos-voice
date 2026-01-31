import 'intent.dart';
import 'intent_type.dart';
import 'intent_payload.dart';
import 'intent_port.dart';

class IntentExecutor {
  final IntentPort port;

  IntentExecutor(this.port);

  Future<void> execute(Intent intent) async {
    switch (intent.type) {
      case IntentType.sellItem:
        final payload = intent.payload as SellItemPayload;
        await port.sellItem(payload);
        break;

      case IntentType.checkout:
        await port.checkout();
        break;

      case IntentType.unknown:
        print('[WARN] Unknown intent ${intent.id}');
        break;
    }
  }
}