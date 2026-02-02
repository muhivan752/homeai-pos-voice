import '../intent/intent.dart';
import '../intent/intent_type.dart';
import 'auth_context.dart';

bool allowIntent(UserRole role, Intent intent) {
  switch (role) {
    case UserRole.barista:
      // Barista dapat menjual item dan checkout
      return intent.type == IntentType.sellItem ||
          intent.type == IntentType.checkout;
    case UserRole.spv:
      // Supervisor memiliki akses penuh
      return true;
    case UserRole.owner:
      // Owner memiliki akses penuh
      return true;
  }
}