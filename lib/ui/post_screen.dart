late final VoiceCommandCoordinator coordinator;

@override
void initState() {
  super.initState();

  coordinator = VoiceCommandCoordinator(
    auth: AuthContext(UserRole.barista),
    parser: IntentParser(),
    executor: IntentExecutor(erpClient),
  );
}

void onMicPressed(String spokenText) {
  coordinator.handleVoice(spokenText);
}