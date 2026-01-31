import 'intent/intent_parser.dart';
import 'intent/intent_executor.dart';
import 'core/erp_sales_adapter.dart';

void main() {
  final text = 'jual kopi susu 2';

  final parser = IntentParser();
  final erp = ErpSalesAdapter();
  final executor = IntentExecutor(erp);

  final intent = parser.parse(text);
  executor.execute(intent);
}

if (intent.type == IntentType.unknown) {
  print('[WARN] intent not recognized');
  return;
}