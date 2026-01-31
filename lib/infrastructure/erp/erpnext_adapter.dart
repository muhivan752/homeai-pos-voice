import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../../intent/intent_port.dart';
import '../../intent/intent_payload.dart';
import 'erpnext_config.dart';
import 'item_lookup.dart';

/// ERPNext adapter yang implement IntentPort.
/// Semua integrasi ERPNext HARUS lewat adapter ini.
class ERPNextAdapter implements IntentPort {
  final ERPNextConfig config;
  final http.Client _client;
  final ItemLookup _itemLookup;

  /// HTTP timeout (default 30 detik)
  static const _timeout = Duration(seconds: 30);

  /// Current draft invoice name (untuk checkout)
  String? _currentInvoiceName;

  /// Items yang sudah ditambahkan (untuk cart aggregation)
  final List<Map<String, dynamic>> _cartItems = [];

  ERPNextAdapter(this.config, {http.Client? client, ItemLookup? itemLookup})
      : _client = client ?? http.Client(),
        _itemLookup = itemLookup ?? ItemLookup(config, client: client);

  Map<String, String> get _headers => {
        'Authorization': 'token ${config.apiKey}:${config.apiSecret}',
        'Content-Type': 'application/json',
      };

  @override
  Future<void> sellItem(SellItemPayload payload) async {
    // Lookup item_code dari ERPNext (dengan fallback ke naive mapping)
    final itemCode = await _itemLookup.lookupOrFallback(payload.item);

    // Tambah ke cart (aggregation)
    _cartItems.add({
      'item_code': itemCode,
      'qty': payload.qty,
      'warehouse': config.warehouse,
    });

    // Buat atau update invoice
    try {
      if (_currentInvoiceName == null) {
        await _createInvoice();
      } else {
        await _updateInvoice();
      }
    } on TimeoutException {
      throw ERPNextError('Koneksi timeout. Cek koneksi internet.');
    } on SocketException {
      throw ERPNextError('Tidak bisa terhubung ke server ERPNext.');
    } on http.ClientException catch (e) {
      throw ERPNextError('Network error: ${e.message}');
    }
  }

  Future<void> _createInvoice() async {
    final url = Uri.parse('${config.baseUrl}/api/resource/POS Invoice');

    final body = {
      'doctype': 'POS Invoice',
      'customer': config.defaultCustomer,
      'pos_profile': config.posProfile,
      'items': _cartItems,
    };

    final res = await _client
        .post(url, headers: _headers, body: jsonEncode(body))
        .timeout(_timeout);

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw ERPNextError(_parseErrorMessage(res, 'Gagal membuat invoice'));
    }

    final data = jsonDecode(res.body);
    _currentInvoiceName = data['data']?['name'];
  }

  Future<void> _updateInvoice() async {
    final url = Uri.parse(
      '${config.baseUrl}/api/resource/POS Invoice/$_currentInvoiceName',
    );

    final body = {'items': _cartItems};

    final res = await _client
        .put(url, headers: _headers, body: jsonEncode(body))
        .timeout(_timeout);

    if (res.statusCode != 200) {
      throw ERPNextError(_parseErrorMessage(res, 'Gagal update invoice'));
    }
  }

  @override
  Future<void> checkout() async {
    if (_currentInvoiceName == null || _cartItems.isEmpty) {
      throw ERPNextError('Tidak ada item untuk checkout.');
    }

    try {
      final url = Uri.parse(
        '${config.baseUrl}/api/resource/POS Invoice/$_currentInvoiceName',
      );

      final res = await _client
          .put(url, headers: _headers, body: jsonEncode({'docstatus': 1}))
          .timeout(_timeout);

      if (res.statusCode != 200) {
        throw ERPNextError(_parseErrorMessage(res, 'Checkout gagal'));
      }

      // Clear state setelah checkout berhasil
      _currentInvoiceName = null;
      _cartItems.clear();
    } on TimeoutException {
      throw ERPNextError('Checkout timeout. Coba lagi.');
    } on SocketException {
      throw ERPNextError('Tidak bisa terhubung ke server ERPNext.');
    } on http.ClientException catch (e) {
      throw ERPNextError('Network error: ${e.message}');
    }
  }

  /// Parse error message dari response ERPNext
  String _parseErrorMessage(http.Response res, String defaultMsg) {
    try {
      final data = jsonDecode(res.body);
      // ERPNext biasanya return error di exc atau message
      final exc = data['exc'] ?? data['message'] ?? data['_server_messages'];
      if (exc != null && exc.toString().isNotEmpty) {
        return '$defaultMsg: $exc';
      }
    } catch (_) {
      // Ignore parse errors
    }
    return '$defaultMsg (${res.statusCode})';
  }
}

class ERPNextError implements Exception {
  final String message;
  ERPNextError(this.message);

  @override
  String toString() => message;
}
