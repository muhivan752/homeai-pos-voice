import 'intent_payload.dart';

abstract class IntentPort {
  Future<void> sellItem(SellItemPayload payload);
  Future<void> checkout(CheckoutPayload payload);
  Future<void> cancelItem(CancelItemPayload payload);
  Future<Map<String, int>> checkStock(CheckStockPayload payload);
  Future<Map<String, dynamic>> dailyReport();
}
