import '../lib/intent/intent_parser.dart';
import '../lib/intent/intent_executor.dart';
import '../lib/intent/intent_type.dart';
import '../lib/intent/mock_intent_port.dart';

void main() async {
  final text = 'jual kopi susu 2';

  final parser = IntentParser();
  final port = MockIntentPort();
  final executor = IntentExecutor(port);

  final intent = parser.parse(text);

  if (intent.type == IntentType.unknown) {
    print('[WARN] intent not recognized');
    return;
  }

  await executor.execute(intent);
  print('[OK] intent executed: ${intent.type}');
}
