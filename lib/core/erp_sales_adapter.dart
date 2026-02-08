import '../intent/intent_port.dart';
import '../intent/intent_payload.dart';

class ErpSalesAdapter implements IntentPort {
  @override
  Future<void> sellItem(SellItemPayload payload) async {
    // In real implementation, this would call ERP API
    print('[ERP] sell item: ${payload.item} x ${payload.qty}');
  }

  @override
  Future<void> checkout() async {
    // In real implementation, this would finalize the sale in ERP
    print('[ERP] checkout completed');
  }
}
