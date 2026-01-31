import '../intent/intent.dart';
import '../intent/intent_type.dart';
import '../infrastructure/intent_parser.dart';
import 'intent_executor.dart';
import '../infrastructure/auth/auth_context.dart';
import '../infrastructure/auth/role_gatekeeper.dart';

/// PosVoiceService - Single orchestration point untuk voice commands.
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
  /// Returns VoiceResult yang bisa ditampilkan ke user.
  Future<VoiceResult> handleVoice(String rawText) async {
    // 1. Parse text ke Intent
    final intent = _parser.parse(rawText);

    // 2. Check unknown intent
    if (intent.type == IntentType.unknown) {
      return VoiceResult.error('Perintah tidak dikenali: "$rawText"');
    }

    // 3. Check authorization
    if (!_gatekeeper.allow(_auth.role, intent)) {
      return VoiceResult.error(
        'Akses ditolak untuk role ${_auth.role.name}',
      );
    }

    // 4. Execute
    try {
      await _executor.execute(intent);
      return VoiceResult.success(_describeIntent(intent));
    } catch (e) {
      return VoiceResult.error(e.toString());
    }
  }

  String _describeIntent(Intent intent) {
    switch (intent.type) {
      case IntentType.sellItem:
        return 'Item ditambahkan';
      case IntentType.checkout:
        return 'Checkout berhasil';
      case IntentType.unknown:
        return 'Unknown';
    }
  }
}

/// Result dari voice command processing.
class VoiceResult {
  final bool isSuccess;
  final String message;

  VoiceResult._(this.isSuccess, this.message);

  factory VoiceResult.success(String message) => VoiceResult._(true, message);
  factory VoiceResult.error(String message) => VoiceResult._(false, message);
}
