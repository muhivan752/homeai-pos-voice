import '../intent/intent_port.dart';
import '../intent/intent_payload.dart';

class MockIntentPort implements IntentPort {
  @override
  Future<void> sellItem(SellItemPayload payload) async {
    print('EXEC: sell ${payload.item} x${payload.qty}');
  }

  @override
  Future<void> checkout() async {
    print('EXEC: checkout');
  }
}