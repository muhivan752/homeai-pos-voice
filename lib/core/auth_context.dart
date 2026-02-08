import 'dart:convert';
import 'package:crypto/crypto.dart';

enum UserRole { barista, spv, owner, admin }

class AuthContext {
  final String userId;
  final String username;
  final UserRole role;
  final DateTime loggedInAt;

  AuthContext({
    required this.userId,
    required this.username,
    required this.role,
    DateTime? loggedInAt,
  }) : loggedInAt = loggedInAt ?? DateTime.now();

  bool get isAdmin => role == UserRole.admin || role == UserRole.owner;
  bool get canSync => role == UserRole.admin || role == UserRole.owner || role == UserRole.spv;
}

class AuthService {
  final Map<String, _UserRecord> _users = {};

  AuthService() {
    // Default admin account
    _users['admin'] = _UserRecord(
      userId: 'USR-001',
      username: 'admin',
      passwordHash: _hashPassword('admin123'),
      role: UserRole.admin,
    );
  }

  void addUser({
    required String userId,
    required String username,
    required String password,
    required UserRole role,
  }) {
    _users[username] = _UserRecord(
      userId: userId,
      username: username,
      passwordHash: _hashPassword(password),
      role: role,
    );
  }

  AuthContext? login(String username, String password) {
    final user = _users[username];
    if (user == null) return null;

    final hash = _hashPassword(password);
    if (hash != user.passwordHash) return null;

    return AuthContext(
      userId: user.userId,
      username: user.username,
      role: user.role,
    );
  }

  bool changePassword(String username, String oldPassword, String newPassword) {
    final user = _users[username];
    if (user == null) return false;

    final oldHash = _hashPassword(oldPassword);
    if (oldHash != user.passwordHash) return false;

    _users[username] = _UserRecord(
      userId: user.userId,
      username: user.username,
      passwordHash: _hashPassword(newPassword),
      role: user.role,
    );
    return true;
  }

  List<String> listUsers() => _users.keys.toList();

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }
}

class _UserRecord {
  final String userId;
  final String username;
  final String passwordHash;
  final UserRole role;

  _UserRecord({
    required this.userId,
    required this.username,
    required this.passwordHash,
    required this.role,
  });
}
