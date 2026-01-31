import '../lib/intent/intent_port.dart';
import '../lib/intent/intent_payload.dart';

class MockIntentPort implements IntentPort {
  final List<String> logs = [];

  @override
  Future<void> sellItem(SellItemPayload payload) async {
    logs.add('sellItem: ${payload.item} x${payload.qty}');
  }

  @override
  Future<void> checkout() async {
    logs.add('checkout');
  }
}
