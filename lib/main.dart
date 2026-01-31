import 'core/voice_command_coordinator.dart';
import 'core/auth_context.dart';
import 'intent/intent_parser.dart';
import 'intent/intent_executor.dart';
import 'core/erp_client.dart';

void main() async {
  final coordinator = VoiceCommandCoordinator(
    auth: AuthContext(UserRole.barista),
    parser: IntentParser(),
    executor: IntentExecutor(ERPClient()),
  );

  await coordinator.handleVoice("jual kopi susu 2");
}