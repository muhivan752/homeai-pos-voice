import '../intent/intent.dart';
import '../intent/intent_type.dart';
import '../intent/intent_payload.dart';
import '../intent/intent_port.dart';

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
        throw IntentExecutionError('Unknown intent: ${intent.id}');
    }
  }
}

class IntentExecutionError implements Exception {
  final String message;
  IntentExecutionError(this.message);

  @override
  String toString() => 'IntentExecutionError: $message';
}
