import 'dart:math';

import '../intent/intent.dart';
import '../intent/intent_type.dart';
import '../intent/intent_payload.dart';

/// Phase 1: Core Voice Commerce Parser
/// Translate natural language → Intent
class IntentParser {
  Intent parse(String text) {
    final id = _genId();
    final lower = text.toLowerCase().trim();

    // === CART OPERATIONS ===

    // addItem: "jual kopi susu 2", "tambah es teh", "pesan americano 1"
    if (_matchesAddItem(lower)) {
      final item = _extractItem(lower, _addItemKeywords);
      final qty = _extractQty(lower);
      return Intent(
        id: id,
        type: IntentType.addItem,
        payload: AddItemPayload(item: item, qty: qty),
      );
    }

    // removeItem: "batal kopi susu", "hapus es teh", "remove americano"
    if (_matchesRemoveItem(lower)) {
      final item = _extractItem(lower, _removeItemKeywords);
      return Intent(
        id: id,
        type: IntentType.removeItem,
        payload: RemoveItemPayload(item: item),
      );
    }

    // changeQty: "kopi susu jadi 3", "ubah es teh 2", "ganti qty americano 5"
    if (_matchesChangeQty(lower)) {
      final item = _extractItemForQtyChange(lower);
      final newQty = _extractQty(lower);
      return Intent(
        id: id,
        type: IntentType.changeQty,
        payload: ChangeQtyPayload(item: item, newQty: newQty),
      );
    }

    // clearCart: "kosongkan", "clear", "hapus semua", "batal semua"
    if (_matchesClearCart(lower)) {
      return Intent(
        id: id,
        type: IntentType.clearCart,
        payload: ClearCartPayload(),
      );
    }

    // undoLast: "undo", "batal tadi", "yang tadi batal"
    if (_matchesUndoLast(lower)) {
      return Intent(
        id: id,
        type: IntentType.undoLast,
        payload: UndoLastPayload(),
      );
    }

    // === CHECKOUT ===

    // checkout: "bayar", "checkout", "selesai", "done"
    if (_matchesCheckout(lower)) {
      return Intent(
        id: id,
        type: IntentType.checkout,
        payload: CheckoutPayload(),
      );
    }

    // === INQUIRY ===

    // readTotal: "total", "berapa", "harganya"
    if (_matchesReadTotal(lower)) {
      return Intent(
        id: id,
        type: IntentType.readTotal,
        payload: ReadTotalPayload(),
      );
    }

    // readCart: "isi keranjang", "apa aja", "list order"
    if (_matchesReadCart(lower)) {
      return Intent(
        id: id,
        type: IntentType.readCart,
        payload: ReadCartPayload(),
      );
    }

    // === META ===

    // help: "bantuan", "help", "bisa apa"
    if (_matchesHelp(lower)) {
      return Intent(
        id: id,
        type: IntentType.help,
        payload: HelpPayload(),
      );
    }

    // unknown
    return Intent(
      id: id,
      type: IntentType.unknown,
      payload: UnknownPayload(),
    );
  }

  // === KEYWORDS ===

  static const _addItemKeywords = [
    'jual', 'tambah', 'pesan', 'order', 'mau', 'beli', 'add',
  ];

  static const _removeItemKeywords = [
    'batal', 'hapus', 'remove', 'cancel', 'buang', 'delete',
  ];

  static const _changeQtyKeywords = [
    'jadi', 'ubah', 'ganti', 'change', 'update',
  ];

  static const _clearCartKeywords = [
    'kosongkan', 'clear', 'hapus semua', 'batal semua', 'reset',
  ];

  static const _undoKeywords = [
    'undo', 'batal tadi', 'yang tadi', 'kembalikan',
  ];

  static const _checkoutKeywords = [
    'bayar', 'checkout', 'selesai', 'done', 'finish', 'tutup',
  ];

  static const _readTotalKeywords = [
    'total', 'berapa', 'harga', 'jumlah', 'hitung',
  ];

  static const _readCartKeywords = [
    'keranjang', 'cart', 'isi', 'apa aja', 'list', 'daftar',
  ];

  static const _helpKeywords = [
    'bantuan', 'help', 'bisa apa', 'tolong', 'cara',
  ];

  // === MATCHERS ===

  bool _matchesAddItem(String text) {
    return _addItemKeywords.any((k) => text.contains(k)) &&
        !_matchesRemoveItem(text) &&
        !_matchesClearCart(text);
  }

  bool _matchesRemoveItem(String text) {
    // "batal X" tapi bukan "batal semua" atau "batal tadi"
    return _removeItemKeywords.any((k) => text.contains(k)) &&
        !text.contains('semua') &&
        !text.contains('tadi');
  }

  bool _matchesChangeQty(String text) {
    return _changeQtyKeywords.any((k) => text.contains(k));
  }

  bool _matchesClearCart(String text) {
    return _clearCartKeywords.any((k) => text.contains(k));
  }

  bool _matchesUndoLast(String text) {
    return _undoKeywords.any((k) => text.contains(k));
  }

  bool _matchesCheckout(String text) {
    return _checkoutKeywords.any((k) => text.contains(k));
  }

  bool _matchesReadTotal(String text) {
    return _readTotalKeywords.any((k) => text.contains(k)) &&
        !_matchesReadCart(text);
  }

  bool _matchesReadCart(String text) {
    return _readCartKeywords.any((k) => text.contains(k));
  }

  bool _matchesHelp(String text) {
    return _helpKeywords.any((k) => text.contains(k));
  }

  // === EXTRACTORS ===

  int _extractQty(String text) {
    final match = RegExp(r'\d+').firstMatch(text);
    return match != null ? int.parse(match.group(0)!) : 1;
  }

  String _extractItem(String text, List<String> keywordsToRemove) {
    var result = text;
    for (final keyword in keywordsToRemove) {
      result = result.replaceAll(keyword, '');
    }
    // Remove numbers and clean up
    result = result
        .replaceAll(RegExp(r'\d+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return result.isNotEmpty ? result : 'item';
  }

  String _extractItemForQtyChange(String text) {
    // "kopi susu jadi 3" → "kopi susu"
    // Split by change keywords
    for (final keyword in _changeQtyKeywords) {
      if (text.contains(keyword)) {
        final parts = text.split(keyword);
        if (parts.isNotEmpty) {
          return parts[0]
              .replaceAll(RegExp(r'\d+'), '')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
        }
      }
    }
    return 'item';
  }

  String _genId() => Random().nextInt(999999).toString().padLeft(6, '0');
}
