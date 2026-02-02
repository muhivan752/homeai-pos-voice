import 'core/voice_command_coordinator.dart';
import 'core/auth_context.dart';
import 'intent/intent_parser.dart';
import 'intent/intent_executor.dart';
import 'intent/mock_intent_port.dart';

void main() async {
  final coordinator = VoiceCommandCoordinator(
    auth: AuthContext(UserRole.barista),
    parser: IntentParser(),
    executor: IntentExecutor(MockIntentPort()),
  );

  // Demo: test berbagai perintah voice
  await coordinator.handleVoice("jual kopi susu 2");
  await coordinator.handleVoice("jual es teh manis 3");
  await coordinator.handleVoice("bayar");
}