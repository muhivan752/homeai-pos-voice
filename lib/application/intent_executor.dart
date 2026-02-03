import '../domain/domain.dart';

/// Phase 1: Core Voice Commerce Executor
/// Route Intent ke ERPPort operations.
class IntentExecutor {
  final ERPPort port;

  IntentExecutor(this.port);

  /// Execute intent dan return response untuk voice feedback.
  Future<ExecutionResult> execute(Intent intent) async {
    switch (intent.type) {
      // === CART OPERATIONS ===

      case IntentType.addItem:
        final payload = intent.payload as AddItemPayload;
        await port.addItem(payload);
        return ExecutionResult.success(
          'Ditambahkan ${payload.item} x${payload.qty}',
        );

      case IntentType.removeItem:
        final payload = intent.payload as RemoveItemPayload;
        await port.removeItem(payload);
        return ExecutionResult.success(
          '${payload.item} dihapus dari keranjang',
        );

      case IntentType.changeQty:
        final payload = intent.payload as ChangeQtyPayload;
        await port.changeQty(payload);
        return ExecutionResult.success(
          '${payload.item} diubah jadi ${payload.newQty}',
        );

      case IntentType.clearCart:
        await port.clearCart();
        return ExecutionResult.success('Keranjang dikosongkan');

      case IntentType.undoLast:
        await port.undoLast();
        return ExecutionResult.success('Dibatalkan');

      // === CHECKOUT ===

      case IntentType.checkout:
        await port.checkout();
        return ExecutionResult.success('Pembayaran berhasil');

      // === INQUIRY ===

      case IntentType.readTotal:
        final total = await port.readTotal();
        return ExecutionResult.success(
          'Total ${total.itemCount} item: Rp ${_formatCurrency(total.grandTotal)}',
        );

      case IntentType.readCart:
        final items = await port.readCart();
        if (items.isEmpty) {
          return ExecutionResult.success('Keranjang kosong');
        }
        final itemList = items
            .map((i) => '${i.item} x${i.qty}')
            .join(', ');
        return ExecutionResult.success('Isi keranjang: $itemList');

      // === META ===

      case IntentType.help:
        return ExecutionResult.success(_helpText);

      case IntentType.unknown:
        return ExecutionResult.error(
          'Maaf, saya tidak paham. Coba bilang "bantuan" untuk daftar perintah.',
        );
    }
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }

  static const _helpText = '''
Perintah yang bisa saya bantu:
• "jual [item] [jumlah]" - tambah item
• "batal [item]" - hapus item
• "[item] jadi [jumlah]" - ubah jumlah
• "kosongkan" - hapus semua
• "undo" - batal yang tadi
• "bayar" - checkout
• "total" - lihat total
• "keranjang" - lihat isi
''';
}

/// Hasil eksekusi intent untuk voice feedback.
class ExecutionResult {
  final bool isSuccess;
  final String message;

  ExecutionResult._(this.isSuccess, this.message);

  factory ExecutionResult.success(String message) =>
      ExecutionResult._(true, message);

  factory ExecutionResult.error(String message) =>
      ExecutionResult._(false, message);
}
