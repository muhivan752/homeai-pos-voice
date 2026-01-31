import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../intent/intent_port.dart';
import '../../intent/intent_payload.dart';
import 'erpnext_config.dart';

/// ERPNext adapter yang implement IntentPort.
/// Semua integrasi ERPNext HARUS lewat adapter ini.
class ERPNextAdapter implements IntentPort {
  final ERPNextConfig config;
  final http.Client _client;

  /// Current draft invoice name (untuk checkout)
  String? _currentInvoiceName;

  ERPNextAdapter(this.config, {http.Client? client})
      : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'Authorization': 'token ${config.apiKey}:${config.apiSecret}',
        'Content-Type': 'application/json',
      };

  @override
  Future<void> sellItem(SellItemPayload payload) async {
    final url = Uri.parse('${config.baseUrl}/api/resource/POS Invoice');

    final body = {
      'doctype': 'POS Invoice',
      'customer': config.defaultCustomer,
      'pos_profile': config.posProfile,
      'items': [
        {
          'item_code': _mapItemCode(payload.item),
          'qty': payload.qty,
          'warehouse': config.warehouse,
        }
      ],
    };

    final res = await _client.post(
      url,
      headers: _headers,
      body: jsonEncode(body),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw ERPNextError('sellItem failed: ${res.statusCode} ${res.body}');
    }

    // Extract invoice name dari response untuk checkout nanti
    final data = jsonDecode(res.body);
    _currentInvoiceName = data['data']?['name'];
  }

  @override
  Future<void> checkout() async {
    if (_currentInvoiceName == null) {
      throw ERPNextError('checkout failed: no active invoice');
    }

    final url = Uri.parse(
      '${config.baseUrl}/api/resource/POS Invoice/$_currentInvoiceName',
    );

    // Submit invoice
    final res = await _client.put(
      url,
      headers: _headers,
      body: jsonEncode({'docstatus': 1}),
    );

    if (res.statusCode != 200) {
      throw ERPNextError('checkout failed: ${res.statusCode} ${res.body}');
    }

    // Clear state setelah checkout
    _currentInvoiceName = null;
  }

  /// Mapping naive: "kopi susu" → "kopi_susu"
  /// TODO: Implement proper item lookup dari ERPNext
  String _mapItemCode(String item) {
    return item.toLowerCase().replaceAll(' ', '_');
  }
}

class ERPNextError implements Exception {
  final String message;
  ERPNextError(this.message);

  @override
  String toString() => 'ERPNextError: $message';
}
