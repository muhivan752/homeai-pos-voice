enum IntentType {
  sellItem,
  checkout,
  unknown,
}

class Intent {
  final IntentType type;
  final Map<String, dynamic> payload;

  Intent(this.type, this.payload);
}