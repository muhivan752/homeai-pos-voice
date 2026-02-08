import '../core/voice_command_coordinator.dart';

class VoiceInput {
  final VoiceCommandCoordinator coordinator;
  final void Function(String response)? onResponse;

  VoiceInput({
    required this.coordinator,
    this.onResponse,
  });

  Future<void> onSpeechResult(String recognizedText) async {
    final response = await coordinator.handleVoice(recognizedText);
    onResponse?.call(response);
  }
}
