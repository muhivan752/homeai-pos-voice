enum UserRole { barista, spv, owner }

class AuthContext {
  final UserRole role;
  AuthContext(this.role);
}