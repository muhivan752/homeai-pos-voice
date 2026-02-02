import 'dart:convert';
import 'package:http/http.dart' as http;
import '../intent/intent_port.dart';
import '../intent/intent_payload.dart';

class ERPClient implements IntentPort {
  final String baseUrl;
  final String apiKey;
  final String apiSecret;

  ERPClient({
    required this.baseUrl,
    required this.apiKey,
    required this.apiSecret,
  });

  @override
  Future<void> sellItem(SellItemPayload payload) async {
    await createSalesInvoice(itemCode: payload.item, qty: payload.qty);
  }

  @override
  Future<void> checkout() async {
    // ERP checkout logic - for now just print
    print('[ERP] Checkout completed');
  }

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
    ).timeout(const Duration(seconds: 30));

    // Accept any 2xx status code
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        'ERP_SALES_INVOICE_FAILED: ${res.statusCode} ${res.body}',
      );
    }
  }
}