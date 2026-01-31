sealed class IntentPayload {}

class SellItemPayload extends IntentPayload {
  final String item;
  final int qty;

  SellItemPayload({
    required this.item,
    required this.qty,
  });
}

class CheckoutPayload extends IntentPayload {}

class UnknownPayload extends IntentPayload {}