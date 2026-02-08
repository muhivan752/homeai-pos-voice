import 'dart:convert';
import 'package:http/http.dart' as http;

class ERPClient {
  final String baseUrl;
  final String apiKey;
  final String apiSecret;

  ERPClient({
    required this.baseUrl,
    required this.apiKey,
    required this.apiSecret,
  });

  Map<String, String> get _headers => {
        'Authorization': 'token $apiKey:$apiSecret',
        'Content-Type': 'application/json',
      };

  // --- Sales Invoice ---

  Future<void> createSalesInvoice({
    required String itemCode,
    required int qty,
    String paymentMethod = 'Cash',
  }) async {
    final url = Uri.parse('$baseUrl/api/resource/Sales Invoice');

    final payload = {
      "customer": "Walk-in Customer",
      "items": [
        {"item_code": itemCode, "qty": qty}
      ],
      "payments": [
        {"mode_of_payment": paymentMethod, "amount": 0}
      ]
    };

    final res = await http.post(url, headers: _headers, body: jsonEncode(payload));

    if (res.statusCode != 200) {
      throw Exception('ERP_SALES_INVOICE_FAILED: ${res.statusCode} ${res.body}');
    }
  }

  // --- Stock ---

  Future<Map<String, int>> getStock() async {
    final url = Uri.parse('$baseUrl/api/resource/Bin?fields=["item_code","actual_qty"]&limit_page_length=100');

    try {
      final res = await http.get(url, headers: _headers);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body['data'] as List<dynamic>? ?? [];
        final stock = <String, int>{};
        for (final item in data) {
          stock[item['item_code'] as String] = (item['actual_qty'] as num).toInt();
        }
        return stock;
      }
    } catch (_) {}
    return {};
  }

  // --- Connection Check ---

  Future<bool> isOnline() async {
    try {
      final url = Uri.parse('$baseUrl/api/method/frappe.auth.get_logged_user');
      final res = await http.get(url, headers: _headers)
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
