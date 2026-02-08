import 'auth_context.dart';
import '../intent/intent.dart';
import '../intent/intent_type.dart';

bool allowIntent(UserRole role, Intent intent) {
  switch (role) {
    case UserRole.barista:
      return intent.type == IntentType.sellItem ||
          intent.type == IntentType.checkout;

    case UserRole.supervisor:
      return intent.type == IntentType.sellItem ||
          intent.type == IntentType.checkout;

    case UserRole.owner:
      return intent.type == IntentType.checkout;

    case UserRole.admin:
      return true;
  }
}
