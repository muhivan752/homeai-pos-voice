import '../intent/intent_parser.dart';
import '../intent/intent_executor.dart';
import '../intent/intent.dart';
import '../core/auth_context.dart';
import '../core/role_gatekeeper.dart';

typedef VoiceCallback = void Function(String message, bool isSuccess);

class VoiceCommandCoordinator {
  final AuthContext auth;
  final IntentParser parser;
  final IntentExecutor executor;
  final VoiceCallback? onResult;

  VoiceCommandCoordinator({
    required this.auth,
    required this.parser,
    required this.executor,
    this.onResult,
  });

  Future<VoiceResult> handleVoice(String rawText) async {
    final intent = parser.parse(rawText);

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
