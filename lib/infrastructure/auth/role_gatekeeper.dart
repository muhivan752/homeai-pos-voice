import '../../domain/intent/intent.dart';
import '../../domain/intent/intent_type.dart';
import 'auth_context.dart';

/// Role-based access control untuk intent.
///
/// Principle:
/// - Customer = speed (read-only, no modifications)
/// - Staff = safety (operations within role limits)
/// - Owner = intelligence (full access)
class RoleGatekeeper {
  bool allow(UserRole role, Intent intent) {
    switch (role) {
      case UserRole.customer:
        return _customerAllowed.contains(intent.type);

      case UserRole.barista:
        return _baristaAllowed.contains(intent.type);

      case UserRole.spv:
        return _spvAllowed.contains(intent.type);

      case UserRole.owner:
        // Owner bisa semua
        return true;
    }
  }

  /// Get list of allowed intent types for a role.
  Set<IntentType> getAllowedIntents(UserRole role) {
    switch (role) {
      case UserRole.customer:
        return _customerAllowed;
      case UserRole.barista:
        return _baristaAllowed;
      case UserRole.spv:
        return _spvAllowed;
      case UserRole.owner:
        return IntentType.values.toSet();
    }
  }

  /// Customer: Read-only access for speed.
  /// - Can view cart and total
  /// - Can ask for help
  /// - Cannot modify anything
  static const _customerAllowed = {
    IntentType.readTotal,
    IntentType.readCart,
    IntentType.help,
  };

  /// Barista: Basic staff operations.
  /// - All cart operations
  /// - Checkout
  /// - Inquiry
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
    // Help
    IntentType.help,
  };

  /// SPV: Supervisor operations.
  /// - All barista intents
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
    IntentType.help,
    // Phase 2 (nanti): applyDiscount, selectPayment
    // Phase 4 (nanti): openShift, closeShift
  };
}
