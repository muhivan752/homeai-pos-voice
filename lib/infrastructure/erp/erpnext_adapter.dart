import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../intent/intent_port.dart';
import '../../intent/intent_payload.dart';

/// ERPNext adapter yang implement IntentPort.
/// Semua integrasi ERPNext HARUS lewat adapter ini.
class ERPNextAdapter implements IntentPort {
  final String baseUrl;
  final String apiKey;
  final String apiSecret;

  ERPNextAdapter({
    required this.baseUrl,
    required this.apiKey,
    required this.apiSecret,
  });

  Map<String, String> get _headers => {
        'Authorization': 'token $apiKey:$apiSecret',
        'Content-Type': 'application/json',
      };

  @override
  Future<void> sellItem(SellItemPayload payload) async {
    // Untuk POS, kita tambahkan item ke draft invoice
    // atau buat baru jika belum ada
    final url = Uri.parse('$baseUrl/api/resource/POS Invoice');

    final body = {
      'doctype': 'POS Invoice',
      'customer': 'Walk-in Customer',
      'items': [
        {
          'item_code': payload.item,
          'qty': payload.qty,
        }
      ],
    };

    final res = await http.post(url, headers: _headers, body: jsonEncode(body));

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw ERPNextError(
        'sellItem failed: ${res.statusCode} ${res.body}',
      );
    }
  }

  @override
  Future<void> checkout() async {
    // Submit POS Invoice (finalize transaction)
    // Dalam implementasi real, perlu track invoice yang sedang aktif
    final url = Uri.parse('$baseUrl/api/method/erpnext.selling.doctype.pos_invoice.pos_invoice.submit_invoice');

    final res = await http.post(url, headers: _headers);

    if (res.statusCode != 200) {
      throw ERPNextError(
        'checkout failed: ${res.statusCode} ${res.body}',
      );
    }
  }
}

class ERPNextError implements Exception {
  final String message;
  ERPNextError(this.message);

  @override
  String toString() => 'ERPNextError: $message';
}
