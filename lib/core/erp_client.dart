import 'dart:convert';
import 'package:http/http.dart' as http;

class ERPClient {
  final String baseUrl;
  final String apiKey;
  final String apiSecret;

  ERPClient({
    this.baseUrl = '',
    this.apiKey = '',
    this.apiSecret = '',
  });

  Future<Map<String, dynamic>> createSalesInvoice({
    required String itemCode,
    required int qty,
    required double price,
  }) async {
    if (baseUrl.isEmpty) {
      // Mock response for demo
      return {
        'success': true,
        'invoice_id': 'INV-${DateTime.now().millisecondsSinceEpoch}',
        'item_code': itemCode,
        'qty': qty,
        'total': price * qty,
      };
    }

    final url = Uri.parse('$baseUrl/api/resource/Sales Invoice');

    final payload = {
      "customer": "Walk-in Customer",
      "items": [
        {
          "item_code": itemCode,
          "qty": qty,
        }
      ],
      "payments": [
        {
          "mode_of_payment": "Cash",
          "amount": price * qty,
        }
      ]
    };

    final res = await http.post(
      url,
      headers: {
        'Authorization': 'token $apiKey:$apiSecret',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) {
      throw Exception(
        'ERP_SALES_INVOICE_FAILED: ${res.statusCode} ${res.body}',
      );
    }

    return jsonDecode(res.body);
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    if (baseUrl.isEmpty) {
      // Mock products for demo
      return [
        {'item_code': 'kopi-susu', 'name': 'Kopi Susu', 'price': 18000},
        {'item_code': 'es-teh', 'name': 'Es Teh', 'price': 8000},
        {'item_code': 'americano', 'name': 'Americano', 'price': 22000},
      ];
    }

    final url = Uri.parse('$baseUrl/api/resource/Item');

    final res = await http.get(
      url,
      headers: {
        'Authorization': 'token $apiKey:$apiSecret',
        'Content-Type': 'application/json',
      },
    );

    if (res.statusCode != 200) {
      throw Exception(
        'ERP_GET_PRODUCTS_FAILED: ${res.statusCode} ${res.body}',
      );
    }

    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data['data'] ?? []);
  }
}
