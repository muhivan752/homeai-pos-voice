enum IntentType {
  sellItem,
  checkout,
  unknown,
}

class Intent {
  final IntentType type;
  final IntentPayload payload;

  Intent(this.type, this.payload);
}