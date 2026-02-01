import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../../intent/intent_port.dart';
import '../../intent/intent_payload.dart';
import 'erpnext_config.dart';
import 'item_lookup.dart';

/// ERPNext adapter Phase 1: Core Voice Commerce
/// Implements IntentPort untuk semua cart operations.
///
/// ATURAN:
/// 1. Semua operasi via POS Invoice draft
/// 2. Undo scope HANYA untuk add/remove
/// 3. changeQty dan clearCart = destructive (no undo)
/// 4. checkout = submit invoice (docstatus 1)
class ERPNextAdapter implements IntentPort {
  final ERPNextConfig config;
  final http.Client _client;
  final ItemLookup _itemLookup;

  /// HTTP timeout (default 30 detik)
  static const _timeout = Duration(seconds: 30);

  /// Current draft invoice name
  String? _currentInvoiceName;

  /// Local cart state untuk tracking (sync dengan ERPNext)
  final List<_CartEntry> _cart = [];

  /// Undo stack - HANYA add/remove
  final List<_UndoAction> _undoStack = [];

  ERPNextAdapter(this.config, {http.Client? client, ItemLookup? itemLookup})
      : _client = client ?? http.Client(),
        _itemLookup = itemLookup ?? ItemLookup(config, client: client);

  Map<String, String> get _headers => {
        'Authorization': 'token ${config.apiKey}:${config.apiSecret}',
        'Content-Type': 'application/json',
      };

  // ══════════════════════════════════════════════════════════════
  // CART OPERATIONS
  // ══════════════════════════════════════════════════════════════

  @override
  Future<void> addItem(AddItemPayload payload) async {
    final itemCode = await _itemLookup.lookupOrFallback(payload.item);

    // Add to local cart
    final entry = _CartEntry(
      item: payload.item,
      itemCode: itemCode,
      qty: payload.qty,
    );
    _cart.add(entry);

    // Sync to ERPNext
    await _syncCartToERP();

    // Record for undo (ALLOWED)
    _undoStack.add(_UndoAction.add(entry));

    print('[ERPNext] + ${payload.item} x${payload.qty}');
  }

  @override
  Future<void> removeItem(RemoveItemPayload payload) async {
    final index = _cart.indexWhere(
      (e) => e.item.toLowerCase() == payload.item.toLowerCase(),
    );

    if (index == -1) {
      throw ERPNextError('Item "${payload.item}" tidak ada di keranjang.');
    }

    final removed = _cart.removeAt(index);

    // Sync to ERPNext
    await _syncCartToERP();

    // Record for undo (ALLOWED)
    _undoStack.add(_UndoAction.remove(removed));

    print('[ERPNext] - ${payload.item}');
  }

  @override
  Future<void> changeQty(ChangeQtyPayload payload) async {
    final index = _cart.indexWhere(
      (e) => e.item.toLowerCase() == payload.item.toLowerCase(),
    );

    if (index == -1) {
      throw ERPNextError('Item "${payload.item}" tidak ada di keranjang.');
    }

    // Update local cart
    final old = _cart[index];
    _cart[index] = _CartEntry(
      item: old.item,
      itemCode: old.itemCode,
      qty: payload.newQty,
    );

    // Sync to ERPNext
    await _syncCartToERP();

    // ⚠️ changeQty = DESTRUCTIVE (clear undo stack)
    _undoStack.clear();

    print('[ERPNext] ${payload.item}: qty → ${payload.newQty}');
  }

  @override
  Future<void> clearCart() async {
    if (_cart.isEmpty) {
      throw ERPNextError('Keranjang sudah kosong.');
    }

    // Clear local cart
    _cart.clear();

    // Cancel/delete draft invoice if exists
    if (_currentInvoiceName != null) {
      await _deleteInvoice();
    }

    // ⚠️ clearCart = DESTRUCTIVE (clear undo stack)
    _undoStack.clear();

    print('[ERPNext] Keranjang dikosongkan.');
  }

  @override
  Future<void> undoLast() async {
    // ⚠️ UNDO HANYA UNTUK ADD/REMOVE
    if (_undoStack.isEmpty) {
      throw ERPNextError(
        'Tidak ada yang bisa di-undo. Undo hanya untuk tambah/hapus item terakhir.',
      );
    }

    final action = _undoStack.removeLast();

    switch (action.type) {
      case _UndoType.add:
        // Undo add = remove item
        _cart.remove(action.entry);
        print('[ERPNext] Undo: hapus ${action.entry!.item}');
        break;

      case _UndoType.remove:
        // Undo remove = add item back
        _cart.add(action.entry!);
        print('[ERPNext] Undo: kembalikan ${action.entry!.item}');
        break;
    }

    // Sync changes to ERPNext
    await _syncCartToERP();
  }

  // ══════════════════════════════════════════════════════════════
  // CHECKOUT
  // ══════════════════════════════════════════════════════════════

  @override
  Future<void> checkout() async {
    if (_cart.isEmpty || _currentInvoiceName == null) {
      throw ERPNextError('Tidak ada item untuk checkout. Tambah item dulu.');
    }

    try {
      // First, get the grand total
      final total = await readTotal();

      // Update payment amount and submit invoice
      final url = Uri.parse(
        '${config.baseUrl}/api/resource/POS Invoice/$_currentInvoiceName',
      );

      final res = await _client
          .put(
            url,
            headers: _headers,
            body: jsonEncode({
              'payments': [
                {
                  'mode_of_payment': 'Cash',
                  'amount': total.grandTotal,
                }
              ],
              'docstatus': 1,
            }),
          )
          .timeout(_timeout);

      if (res.statusCode != 200) {
        throw ERPNextError(_parseError(res, 'Checkout gagal'));
      }

      print('[ERPNext] === CHECKOUT BERHASIL ===');
      print('[ERPNext] Invoice: $_currentInvoiceName');

      // Clear state
      _currentInvoiceName = null;
      _cart.clear();
      _undoStack.clear();
    } on TimeoutException {
      throw ERPNextError('Checkout timeout. Coba lagi.');
    } on SocketException {
      throw ERPNextError('Tidak bisa terhubung ke server ERPNext.');
    } on http.ClientException catch (e) {
      throw ERPNextError('Network error: ${e.message}');
    }
  }

  // ══════════════════════════════════════════════════════════════
  // INQUIRY
  // ══════════════════════════════════════════════════════════════

  @override
  Future<CartTotal> readTotal() async {
    if (_currentInvoiceName == null) {
      return CartTotal(
        total: 0,
        discount: 0,
        grandTotal: 0,
        itemCount: 0,
      );
    }

    try {
      final url = Uri.parse(
        '${config.baseUrl}/api/resource/POS Invoice/$_currentInvoiceName',
      );

      final res = await _client.get(url, headers: _headers).timeout(_timeout);

      if (res.statusCode != 200) {
        throw ERPNextError(_parseError(res, 'Gagal membaca total'));
      }

      final data = jsonDecode(res.body)['data'];
      return CartTotal(
        total: (data['total'] ?? 0).toDouble(),
        discount: (data['discount_amount'] ?? 0).toDouble(),
        grandTotal: (data['grand_total'] ?? 0).toDouble(),
        itemCount: (data['items'] as List?)?.length ?? 0,
      );
    } on TimeoutException {
      throw ERPNextError('Koneksi timeout.');
    } on SocketException {
      throw ERPNextError('Tidak bisa terhubung ke server.');
    } on http.ClientException catch (e) {
      throw ERPNextError('Network error: ${e.message}');
    }
  }

  @override
  Future<List<CartItem>> readCart() async {
    if (_currentInvoiceName == null) {
      return [];
    }

    try {
      final url = Uri.parse(
        '${config.baseUrl}/api/resource/POS Invoice/$_currentInvoiceName',
      );

      final res = await _client.get(url, headers: _headers).timeout(_timeout);

      if (res.statusCode != 200) {
        throw ERPNextError(_parseError(res, 'Gagal membaca keranjang'));
      }

      final data = jsonDecode(res.body)['data'];
      final items = data['items'] as List? ?? [];

      return items.map((i) => CartItem(
            item: i['item_name'] ?? i['item_code'],
            itemCode: i['item_code'],
            qty: (i['qty'] ?? 0).toInt(),
            rate: (i['rate'] ?? 0).toDouble(),
            amount: (i['amount'] ?? 0).toDouble(),
          )).toList();
    } on TimeoutException {
      throw ERPNextError('Koneksi timeout.');
    } on SocketException {
      throw ERPNextError('Tidak bisa terhubung ke server.');
    } on http.ClientException catch (e) {
      throw ERPNextError('Network error: ${e.message}');
    }
  }

  // ══════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ══════════════════════════════════════════════════════════════

  /// Sync local cart ke ERPNext (create or update invoice)
  Future<void> _syncCartToERP() async {
    try {
      if (_cart.isEmpty) {
        // Delete invoice if cart empty
        if (_currentInvoiceName != null) {
          await _deleteInvoice();
        }
        return;
      }

      final items = _cart
          .map((e) => {
                'item_code': e.itemCode,
                'qty': e.qty,
                'warehouse': config.warehouse,
              })
          .toList();

      if (_currentInvoiceName == null) {
        // Create new invoice
        await _createInvoice(items);
      } else {
        // Update existing invoice
        await _updateInvoice(items);
      }
    } on TimeoutException {
      throw ERPNextError('Koneksi timeout. Cek koneksi internet.');
    } on SocketException {
      throw ERPNextError('Tidak bisa terhubung ke server ERPNext.');
    } on http.ClientException catch (e) {
      throw ERPNextError('Network error: ${e.message}');
    }
  }

  Future<void> _createInvoice(List<Map<String, dynamic>> items) async {
    final url = Uri.parse('${config.baseUrl}/api/resource/POS Invoice');

    final body = {
      'doctype': 'POS Invoice',
      'customer': config.defaultCustomer,
      'pos_profile': config.posProfile,
      'items': items,
      // POS Invoice requires at least one payment method
      'payments': [
        {
          'mode_of_payment': 'Cash',
          'amount': 0, // Will be updated on checkout
        }
      ],
    };

    final res = await _client
        .post(url, headers: _headers, body: jsonEncode(body))
        .timeout(_timeout);

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw ERPNextError(_parseError(res, 'Gagal membuat invoice'));
    }

    final data = jsonDecode(res.body);
    _currentInvoiceName = data['data']?['name'];
  }

  Future<void> _updateInvoice(List<Map<String, dynamic>> items) async {
    final url = Uri.parse(
      '${config.baseUrl}/api/resource/POS Invoice/$_currentInvoiceName',
    );

    final body = {'items': items};

    final res = await _client
        .put(url, headers: _headers, body: jsonEncode(body))
        .timeout(_timeout);

    if (res.statusCode != 200) {
      throw ERPNextError(_parseError(res, 'Gagal update invoice'));
    }
  }

  Future<void> _deleteInvoice() async {
    if (_currentInvoiceName == null) return;

    final url = Uri.parse(
      '${config.baseUrl}/api/resource/POS Invoice/$_currentInvoiceName',
    );

    try {
      await _client.delete(url, headers: _headers).timeout(_timeout);
    } catch (_) {
      // Ignore delete errors - invoice might already be gone
    }

    _currentInvoiceName = null;
  }

  String _parseError(http.Response res, String defaultMsg) {
    try {
      final data = jsonDecode(res.body);
      final exc = data['exc'] ?? data['message'] ?? data['_server_messages'];
      if (exc != null && exc.toString().isNotEmpty) {
        // Clean up ERPNext error message
        var msg = exc.toString();
        if (msg.contains('ValidationError')) {
          msg = msg.split('ValidationError:').last.trim();
        }
        return '$defaultMsg: $msg';
      }
    } catch (_) {}
    return '$defaultMsg (${res.statusCode})';
  }
}

/// Local cart entry for tracking
class _CartEntry {
  final String item;
  final String itemCode;
  final int qty;

  _CartEntry({
    required this.item,
    required this.itemCode,
    required this.qty,
  });

  @override
  bool operator ==(Object other) =>
      other is _CartEntry &&
      other.item == item &&
      other.itemCode == itemCode &&
      other.qty == qty;

  @override
  int get hashCode => Object.hash(item, itemCode, qty);
}

/// Undo HANYA untuk add/remove
enum _UndoType { add, remove }

class _UndoAction {
  final _UndoType type;
  final _CartEntry? entry;

  _UndoAction._(this.type, {this.entry});

  factory _UndoAction.add(_CartEntry entry) =>
      _UndoAction._(_UndoType.add, entry: entry);

  factory _UndoAction.remove(_CartEntry entry) =>
      _UndoAction._(_UndoType.remove, entry: entry);
}

class ERPNextError implements Exception {
  final String message;
  ERPNextError(this.message);

  @override
  String toString() => message;
}
