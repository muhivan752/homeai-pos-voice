import '../domain/domain.dart';
import '../infrastructure/intent_parser.dart';
import 'intent_executor.dart';
import '../infrastructure/auth/auth_context.dart';
import '../infrastructure/auth/role_gatekeeper.dart';

/// Phase 1: Core Voice Commerce Service
/// Single orchestration point untuk voice commands.
///
/// UI layer HANYA boleh import dan memanggil class ini.
/// Semua wiring dependency dilakukan di entrypoint (bin/).
class PosVoiceService {
  final IntentParser _parser;
  final IntentExecutor _executor;
  final RoleGatekeeper _gatekeeper;
  final AuthContext _auth;

  PosVoiceService({
    required IntentParser parser,
    required IntentExecutor executor,
    required RoleGatekeeper gatekeeper,
    required AuthContext auth,
  })  : _parser = parser,
        _executor = executor,
        _gatekeeper = gatekeeper,
        _auth = auth;

  /// Handle voice command dari UI.
  /// Returns VoiceResult untuk voice feedback.
  Future<VoiceResult> handleVoice(String rawText) async {
    // 1. Parse text ke Intent
    final intent = _parser.parse(rawText);

    // 2. Check authorization (kecuali untuk help & unknown)
    if (intent.type != IntentType.help && intent.type != IntentType.unknown) {
      if (!_gatekeeper.allow(_auth.role, intent)) {
        return VoiceResult.error(
          'Akses ditolak untuk ${_auth.role.name}',
        );
      }
    }

    // 3. Execute dan return result
    try {
      final result = await _executor.execute(intent);
      return VoiceResult._(result.isSuccess, result.message);
    } catch (e) {
      // Translate error ke bahasa manusia
      return VoiceResult.error(_translateError(e.toString()));
    }
  }

  /// Translate technical error ke bahasa manusia
  String _translateError(String error) {
    // Network errors
    if (error.contains('timeout') || error.contains('Timeout')) {
      return 'Koneksi lambat. Coba lagi ya.';
    }
    if (error.contains('Socket') || error.contains('connection')) {
      return 'Tidak bisa konek ke server.';
    }

    // Business errors - sudah dalam bahasa Indonesia dari adapter
    return error;
  }
}

/// Result dari voice command untuk feedback ke user.
class VoiceResult {
  final bool isSuccess;
  final String message;

  VoiceResult._(this.isSuccess, this.message);

  factory VoiceResult.success(String message) => VoiceResult._(true, message);
  factory VoiceResult.error(String message) => VoiceResult._(false, message);
}
