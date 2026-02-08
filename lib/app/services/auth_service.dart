import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';

class AuthService extends ChangeNotifier {
  final _db = DatabaseHelper();

  Map<String, dynamic>? _currentUser;
  bool _isLoggedIn = false;

  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  String get currentUserId => _currentUser?['id'] ?? '';
  String get currentUserName => _currentUser?['name'] ?? 'Guest';
  String get currentUserRole => _currentUser?['role'] ?? 'cashier';
  bool get isAdmin => currentUserRole == 'admin';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('current_user_id');

    if (userId != null) {
      final user = await _db.getUserById(userId);
      if (user != null) {
        _currentUser = user;
        _isLoggedIn = true;
        notifyListeners();
      }
    }
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<AuthResult> login(String username, String password) async {
    try {
      final user = await _db.getUserByUsername(username.toLowerCase().trim());

      if (user == null) {
        return AuthResult(success: false, message: 'Username tidak ditemukan');
      }

      final hashedPassword = _hashPassword(password);
      if (user['password_hash'] != hashedPassword) {
        return AuthResult(success: false, message: 'Password salah');
      }

      _currentUser = user;
      _isLoggedIn = true;

      // Save to prefs
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_id', user['id']);

      notifyListeners();
      return AuthResult(success: true, message: 'Login berhasil');
    } catch (e) {
      return AuthResult(success: false, message: 'Error: $e');
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    _isLoggedIn = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_id');

    notifyListeners();
  }

  Future<AuthResult> createUser({
    required String username,
    required String password,
    required String name,
    String role = 'cashier',
  }) async {
    try {
      final existing = await _db.getUserByUsername(username.toLowerCase().trim());
      if (existing != null) {
        return AuthResult(success: false, message: 'Username sudah digunakan');
      }

      final userId = DateTime.now().millisecondsSinceEpoch.toString();
      await _db.insertUser({
        'id': userId,
        'username': username.toLowerCase().trim(),
        'password_hash': _hashPassword(password),
        'name': name,
        'role': role,
        'is_active': 1,
      });

      return AuthResult(success: true, message: 'User berhasil dibuat');
    } catch (e) {
      return AuthResult(success: false, message: 'Error: $e');
    }
  }

  Future<AuthResult> changePassword(String oldPassword, String newPassword) async {
    if (_currentUser == null) {
      return AuthResult(success: false, message: 'Belum login');
    }

    final hashedOld = _hashPassword(oldPassword);
    if (_currentUser!['password_hash'] != hashedOld) {
      return AuthResult(success: false, message: 'Password lama salah');
    }

    await _db.updateUser(_currentUser!['id'], {
      'password_hash': _hashPassword(newPassword),
    });

    return AuthResult(success: true, message: 'Password berhasil diubah');
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    return await _db.getUsers();
  }
}

class AuthResult {
  final bool success;
  final String message;

  AuthResult({required this.success, required this.message});
}
