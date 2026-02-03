import 'intent_type.dart';
import 'intent_payload.dart';

/// Domain entity representing a parsed voice command intent.
class Intent {
  final String id;
  final IntentType type;
  final IntentPayload payload;

  Intent({
    required this.id,
    required this.type,
    required this.payload,
  });

  @override
  String toString() => 'Intent($type, id: $id)';
}
