import '../../intent/intent.dart';
import '../../intent/intent_type.dart';
import 'auth_context.dart';

/// Phase 1: Role-based access control untuk intent.
/// Menentukan role mana yang boleh execute intent tertentu.
class RoleGatekeeper {
  bool allow(UserRole role, Intent intent) {
    switch (role) {
      case UserRole.barista:
        return _baristaAllowed.contains(intent.type);

      case UserRole.spv:
        return _spvAllowed.contains(intent.type);

      case UserRole.owner:
        // Owner bisa semua
        return true;
    }
  }

  /// Phase 1: Barista allowed intents
  /// - Semua cart operations
  /// - Checkout
  /// - Inquiry (read-only)
  static const _baristaAllowed = {
    // Cart
    IntentType.addItem,
    IntentType.removeItem,
    IntentType.changeQty,
    IntentType.clearCart,
    IntentType.undoLast,
    // Checkout
    IntentType.checkout,
    // Inquiry
    IntentType.readTotal,
    IntentType.readCart,
  };

  /// Phase 1: SPV allowed intents
  /// - Semua yang barista bisa
  /// - (Phase 2: discount, payment method)
  /// - (Phase 4: session management)
  static const _spvAllowed = {
    // Semua barista intents
    IntentType.addItem,
    IntentType.removeItem,
    IntentType.changeQty,
    IntentType.clearCart,
    IntentType.undoLast,
    IntentType.checkout,
    IntentType.readTotal,
    IntentType.readCart,
    // Phase 2 (nanti): applyDiscount, selectPayment
    // Phase 4 (nanti): openShift, closeShift
  };
}
