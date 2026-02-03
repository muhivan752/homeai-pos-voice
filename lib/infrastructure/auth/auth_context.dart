/// User roles in the POS system.
///
/// Principle:
/// - Customer = speed (read-only, view cart/total)
/// - Staff = safety (operations with role-based limits)
/// - Owner = intelligence (full access)
enum UserRole {
  /// Customer mode - read-only, optimized for speed.
  /// Can only view cart and total.
  customer,

  /// Barista - basic staff operations.
  /// Can do cart ops, checkout, inquiries.
  barista,

  /// Supervisor - barista + management ops.
  /// Phase 2: discount, payment method selection.
  spv,

  /// Owner - full access to everything.
  /// Phase 4: session management, reports.
  owner,
}

/// Extension for role utilities.
extension UserRoleX on UserRole {
  /// Display name in Indonesian.
  String get displayName {
    switch (this) {
      case UserRole.customer:
        return 'Pelanggan';
      case UserRole.barista:
        return 'Barista';
      case UserRole.spv:
        return 'Supervisor';
      case UserRole.owner:
        return 'Owner';
    }
  }

  /// Is this a staff role (not customer)?
  bool get isStaff => this != UserRole.customer;

  /// Is this a management role (spv or owner)?
  bool get isManagement =>
      this == UserRole.spv || this == UserRole.owner;
}

/// Authentication context holding current user info.
class AuthContext {
  final UserRole role;
  final String? userId;
  final String? userName;

  AuthContext(
    this.role, {
    this.userId,
    this.userName,
  });

  /// Create guest customer context.
  factory AuthContext.guest() => AuthContext(UserRole.customer);

  /// Create staff context.
  factory AuthContext.staff(UserRole role, {String? userId, String? userName}) {
    assert(role.isStaff, 'Use AuthContext.guest() for customer');
    return AuthContext(role, userId: userId, userName: userName);
  }

  @override
  String toString() => 'AuthContext(${role.displayName}, user: $userName)';
}
