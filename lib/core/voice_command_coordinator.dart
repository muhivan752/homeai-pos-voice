import '../intent/intent.dart';
import '../intent/intent_type.dart';
import '../intent/intent_parser.dart';
import '../intent/intent_executor.dart';
import '../intent/intent.dart';
import '../core/auth_context.dart';
import '../core/role_gatekeeper.dart';
import '../db/local_db.dart';
import '../sync/sync_engine.dart';

typedef VoiceCallback = void Function(String message, bool isSuccess);

class VoiceCommandCoordinator {
  AuthContext? _auth;
  final AuthService authService;
  final IntentParser parser;
  final IntentExecutor executor;
  final VoiceCallback? onResult;

  VoiceCommandCoordinator({
    AuthContext? auth,
    required this.authService,
    required this.parser,
    required this.executor,
    this.onResult,
  });

  Future<VoiceResult> handleVoice(String rawText) async {
    final intent = parser.parse(rawText);

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
      final message = 'Perintah tidak dikenali: "$rawText"';
      onResult?.call(message, false);
      return VoiceResult(success: false, message: message);
    }

    if (!allowIntent(auth.role, intent)) {
      const message = 'Akses ditolak untuk perintah ini';
      onResult?.call(message, false);
      return VoiceResult(success: false, message: message);
    }

    // Handle sync manual
    if (intent.type == IntentType.syncManual) {
      return _handleSync();
    }

    // Eksekusi intent
    try {
      await executor.execute(intent);
      final message = 'Berhasil: ${intent.type.name}';
      onResult?.call(message, true);
      return VoiceResult(success: true, message: message, intent: intent);
    } catch (e) {
      final message = 'Error: ${e.toString()}';
      onResult?.call(message, false);
      return VoiceResult(success: false, message: message);
    }
  }
}

class VoiceResult {
  final bool success;
  final String message;
  final Intent? intent;

  VoiceResult({
    required this.success,
    required this.message,
    this.intent,
  });
}
