import '../intent/intent.dart';
import '../intent/intent_type.dart';
import '../intent/intent_parser.dart';
import '../intent/intent_executor.dart';
import '../intent/intent_payload.dart';
import '../core/auth_context.dart';
import '../core/role_gatekeeper.dart';
import '../db/local_db.dart';
import '../sync/sync_engine.dart';

class VoiceCommandCoordinator {
  AuthContext? _auth;
  final AuthService authService;
  final IntentParser parser;
  final IntentExecutor executor;
  final LocalDB db;
  final SyncEngine syncEngine;

  VoiceCommandCoordinator({
    AuthContext? auth,
    required this.authService,
    required this.parser,
    required this.executor,
    required this.db,
    required this.syncEngine,
  }) : _auth = auth;

  AuthContext? get auth => _auth;
  bool get isLoggedIn => _auth != null;

  void setAuth(AuthContext auth) => _auth = auth;
  void logout() => _auth = null;

  Future<String> handleVoice(String rawText) async {
    final intent = parser.parse(rawText);

    // Login tidak perlu auth
    if (intent.type == IntentType.login) {
      return _handleLogin(intent);
    }

    // Cek apakah sudah login
    if (!isLoggedIn) {
      return _respond(false, 'Belum login. Ucapkan: "login [username] [password]"');
    }

    // Cek hak akses
    if (!intent.isValid) {
      return _respond(false, 'Perintah tidak dikenali: "$rawText"');
    }

    if (!allowIntent(_auth!.role, intent)) {
      return _respond(false, 'AKSES_DITOLAK: ${_auth!.role.name} tidak bisa ${intent.type.name}');
    }

    // Handle sync manual
    if (intent.type == IntentType.syncManual) {
      return _handleSync();
    }

    // Eksekusi intent
    try {
      final result = await executor.execute(intent);

      // Simpan transaksi ke LocalDB
      if (_isTransactional(intent.type)) {
        await db.addTransaction(
          id: intent.id,
          type: intent.type.name,
          data: _intentToData(intent),
        );
      }

      return _respond(true, result);
    } catch (e) {
      return _respond(false, e.toString());
    }
  }

  Future<String> _handleLogin(Intent intent) async {
    final payload = intent.payload as LoginPayload;
    final context = authService.login(payload.username, payload.password);

    if (context == null) {
      return _respond(false, 'Login gagal. Username atau password salah.');
    }

    _auth = context;
    return _respond(true, 'Login berhasil! Selamat datang, ${context.username} (${context.role.name})');
  }

  Future<String> _handleSync() async {
    final result = await syncEngine.syncAll();
    return _respond(true, result.toString());
  }

  bool _isTransactional(IntentType type) {
    return [IntentType.sellItem, IntentType.checkout, IntentType.cancelItem].contains(type);
  }

  Map<String, dynamic> _intentToData(Intent intent) {
    final payload = intent.payload;
    if (payload is SellItemPayload) {
      return {'item': payload.item, 'qty': payload.qty};
    }
    if (payload is CheckoutPayload) {
      return {
        'paymentMethod': payload.paymentMethod,
        'items': db.cart.toList(),
      };
    }
    if (payload is CancelItemPayload) {
      return {'item': payload.item};
    }
    return {};
  }

  String _respond(bool success, String message) {
    final prefix = success ? '[OK]' : '[ERROR]';
    final line = '$prefix $message';
    print(line);
    return line;
  }
}
