import 'intent_payload.dart';

/// Phase 1: Core Voice Commerce
/// Port interface untuk ERPNext operations.
/// Semua integrasi ERPNext HARUS implement interface ini.
abstract class IntentPort {
  // === CART OPERATIONS ===

  /// Tambah item ke cart
  Future<void> addItem(AddItemPayload payload);

  /// Hapus item dari cart
  Future<void> removeItem(RemoveItemPayload payload);

  /// Ubah qty item di cart
  Future<void> changeQty(ChangeQtyPayload payload);

  /// Kosongkan cart
  Future<void> clearCart();

  /// Undo last action
  Future<void> undoLast();

  // === CHECKOUT ===

  /// Submit invoice (bayar)
  Future<void> checkout();

  // === INQUIRY ===

  /// Baca total invoice
  Future<CartTotal> readTotal();

  /// Baca isi cart
  Future<List<CartItem>> readCart();
}

/// Response untuk readTotal
class CartTotal {
  final double total;
  final double discount;
  final double grandTotal;
  final int itemCount;

  CartTotal({
    required this.total,
    required this.discount,
    required this.grandTotal,
    required this.itemCount,
  });
}

/// Response untuk readCart
class CartItem {
  final String item;
  final String itemCode;
  final int qty;
  final double rate;
  final double amount;

  CartItem({
    required this.item,
    required this.itemCode,
    required this.qty,
    required this.rate,
    required this.amount,
  });
}
