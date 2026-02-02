import '../intent/intent.dart';
import '../intent/intent_parser.dart';
import '../intent/intent_executor.dart';
import '../intent/intent_type.dart';
import '../core/auth_context.dart';
import '../core/role_gatekeeper.dart';

class VoiceCommandCoordinator {
  final AuthContext auth;
  final IntentParser parser;
  final IntentExecutor executor;

  VoiceCommandCoordinator({
    required this.auth,
    required this.parser,
    required this.executor,
  });

  Future<void> handleVoice(String rawText) async {
    final intent = parser.parse(rawText);

    if (intent.type == IntentType.unknown) {
      _respondError('INTENT_TIDAK_DIKENALI');
      return;
    }

    if (!allowIntent(auth.role, intent)) {
      _respondError('AKSES_DITOLAK');
      return;
    }

    try {
      await executor.execute(intent);
      _respondSuccess(intent);
    } catch (e) {
      _respondError(e.toString());
    }
  }

  void _respondSuccess(Intent intent) {
    print('✅ Berhasil: ${intent.type}');
  }

  void _respondError(String error) {
    print('❌ Error: $error');
  }
}