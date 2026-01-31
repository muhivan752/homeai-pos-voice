/// Phase 1: Core Voice Commerce
/// Intent types yang 1:1 dengan ERPNext POS operations.
enum IntentType {
  // === CART OPERATIONS ===
  addItem,      // "jual kopi susu 2"
  removeItem,   // "batal kopi susu"
  changeQty,    // "kopi susu jadi 3"
  clearCart,    // "kosongkan keranjang"
  undoLast,     // "batal yang tadi"

  // === CHECKOUT ===
  checkout,     // "bayar" / "selesai"

  // === INQUIRY ===
  readTotal,    // "totalnya berapa"
  readCart,     // "apa aja isi keranjang"

  // === META ===
  unknown,      // tidak dikenali
  help,         // "bantuan" / "bisa apa aja"
}
