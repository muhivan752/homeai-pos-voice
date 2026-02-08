sealed class IntentPayload {}

class SellItemPayload extends IntentPayload {
  final String item;
  final int qty;

  SellItemPayload({required this.item, required this.qty});
}

class CheckoutPayload extends IntentPayload {
  final String paymentMethod;

  CheckoutPayload({this.paymentMethod = 'cash'});
}

class CancelItemPayload extends IntentPayload {
  final String? item;

  CancelItemPayload({this.item});
}

class CheckStockPayload extends IntentPayload {
  final String? item;

  CheckStockPayload({this.item});
}

class DailyReportPayload extends IntentPayload {}

class SyncManualPayload extends IntentPayload {}

class LoginPayload extends IntentPayload {
  final String username;
  final String password;

  LoginPayload({required this.username, required this.password});
}

class UnknownPayload extends IntentPayload {
  final String rawText;

  UnknownPayload({this.rawText = ''});
}
