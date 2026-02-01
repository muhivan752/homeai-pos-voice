import '../entities/cart.dart';
import '../intent/intent_payload.dart';

/// Port interface untuk ERPNext operations.
/// Semua integrasi ERPNext HARUS implement interface ini.
///
/// Clean Architecture: Port ini mendefinisikan kontrak
/// antara domain layer dan infrastructure layer.
abstract class ERPPort {
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
