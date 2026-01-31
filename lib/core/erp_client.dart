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

  Future<void> createSalesInvoice({
    required String itemCode,
    required int qty,
  }) async {
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
          "amount": 0 // ERP auto-calc
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
  }
}