import 'intent_payload.dart';

abstract class IntentPort {
  Future<void> sellItem(SellItemPayload payload);
  Future<void> checkout();
}