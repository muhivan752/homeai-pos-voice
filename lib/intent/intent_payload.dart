/// Phase 1: Core Voice Commerce
/// Payload untuk setiap intent type.
sealed class IntentPayload {}

// === CART OPERATIONS ===

/// "jual kopi susu 2"
class AddItemPayload extends IntentPayload {
  final String item;
  final int qty;

  AddItemPayload({required this.item, required this.qty});
}

/// "batal kopi susu"
class RemoveItemPayload extends IntentPayload {
  final String item;

  RemoveItemPayload({required this.item});
}

/// "kopi susu jadi 3"
class ChangeQtyPayload extends IntentPayload {
  final String item;
  final int newQty;

  ChangeQtyPayload({required this.item, required this.newQty});
}

/// "kosongkan keranjang"
class ClearCartPayload extends IntentPayload {}

/// "batal yang tadi"
class UndoLastPayload extends IntentPayload {}

// === CHECKOUT ===

/// "bayar"
class CheckoutPayload extends IntentPayload {}

// === INQUIRY ===

/// "totalnya berapa"
class ReadTotalPayload extends IntentPayload {}

/// "apa aja isi keranjang"
class ReadCartPayload extends IntentPayload {}

// === META ===

/// Intent tidak dikenali
class UnknownPayload extends IntentPayload {}

/// "bantuan"
class HelpPayload extends IntentPayload {}
