import 'auth_context.dart';
import '../intent/intent.dart';
import '../intent/intent_type.dart';

bool allowIntent(UserRole role, Intent intent) {
  switch (role) {
    case UserRole.barista:
      return [
        IntentType.sellItem,
        IntentType.checkout,
        IntentType.cancelItem,
      ].contains(intent.type);

    case UserRole.spv:
      return [
        IntentType.sellItem,
        IntentType.checkout,
        IntentType.cancelItem,
        IntentType.checkStock,
        IntentType.dailyReport,
        IntentType.syncManual,
      ].contains(intent.type);

    case UserRole.owner:
    case UserRole.admin:
      return true; // Full access
  }
}
