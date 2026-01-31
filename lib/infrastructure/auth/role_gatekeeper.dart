import '../../intent/intent.dart';
import '../../intent/intent_type.dart';
import 'auth_context.dart';

/// Role-based access control untuk intent.
/// Menentukan role mana yang boleh execute intent tertentu.
class RoleGatekeeper {
  bool allow(UserRole role, Intent intent) {
    switch (role) {
      case UserRole.barista:
        // Barista hanya bisa sellItem dan checkout
        return intent.type == IntentType.sellItem ||
            intent.type == IntentType.checkout;

      case UserRole.spv:
        // SPV bisa semua yang barista bisa + future intents
        return intent.type == IntentType.sellItem ||
            intent.type == IntentType.checkout;

      case UserRole.owner:
        // Owner bisa semua
        return true;
    }
  }
}
