import '../core/voice_command_coordinator.dart';
import '../core/auth_context.dart';
import '../core/erp_client.dart';
import '../intent/intent_parser.dart';
import '../intent/intent_executor.dart';
import '../db/local_db.dart';
import '../db/local_intent_port.dart';
import '../sync/sync_engine.dart';
import '../voice/voice_input.dart';

/// Contoh integrasi UI (placeholder untuk Flutter widget)
class PosScreen {
  late final VoiceCommandCoordinator coordinator;
  late final VoiceInput voiceInput;

  void init({required ERPClient erpClient}) {
    final db = LocalDB();
    final localPort = LocalIntentPort(db);
    final syncEngine = SyncEngine(db: db, erp: erpClient);
    final authService = AuthService();

    coordinator = VoiceCommandCoordinator(
      authService: authService,
      parser: IntentParser(),
      executor: IntentExecutor(localPort),
      db: db,
      syncEngine: syncEngine,
    );

    voiceInput = VoiceInput(
      coordinator: coordinator,
      onResponse: (response) {
        print('[UI] $response');
      },
    );
  }

  Future<void> onMicPressed(String spokenText) async {
    await voiceInput.onSpeechResult(spokenText);
  }
}
