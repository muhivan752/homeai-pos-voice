class VoiceInput {
  final void Function(String text) onText;

  VoiceInput({required this.onText});

  void onSpeechResult(String recognizedText) {
    onText(recognizedText);
  }
}