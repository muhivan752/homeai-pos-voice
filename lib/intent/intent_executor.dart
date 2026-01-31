import '../core/erp_sales_adapter.dart';
import 'intent.dart';

class IntentExecutor {
  final ErpSalesAdapter erp;

  IntentExecutor(this.erp);

  void execute(Intent intent) {
    switch (intent.type) {
      case IntentType.sellItem:
        erp.addItem(
          item: intent.payload['item'],
          qty: intent.payload['qty'],
        );
        break;

      case IntentType.checkout:
        erp.checkout();
        break;

      default:
        print('[EXEC] unknown intent');
    }
  }
}