enum UserRole {
  barista,
  supervisor,
  owner,
  admin,
}

class AuthContext {
  final UserRole role;
  final String? userId;
  final String? userName;

  AuthContext({
    required this.role,
    this.userId,
    this.userName,
  });

  bool get isBarista => role == UserRole.barista;
  bool get isSupervisor => role == UserRole.supervisor;
  bool get isOwner => role == UserRole.owner;
  bool get isAdmin => role == UserRole.admin;

  bool canSell() => role == UserRole.barista || role == UserRole.admin;
  bool canCheckout() => role == UserRole.barista || role == UserRole.admin;
  bool canManageStock() => role == UserRole.supervisor || role == UserRole.admin;
  bool canViewReports() => role == UserRole.owner || role == UserRole.admin;
}
