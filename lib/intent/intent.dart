import 'intent_type.dart';
import 'intent_payload.dart';

class Intent {
  final String id;
  final IntentType type;
  final IntentPayload payload;
  final DateTime createdAt;

  Intent({
    required this.id,
    required this.type,
    required this.payload,
  });

  bool get isValid => type != IntentType.unknown;
}
