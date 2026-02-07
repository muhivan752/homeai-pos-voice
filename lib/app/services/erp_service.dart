import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ErpService {
  static const String _keyUrl = 'erp_url';
  static const String _keyApiKey = 'erp_api_key';
  static const String _keyApiSecret = 'erp_api_secret';

  String? _baseUrl;
  String? _apiKey;
  String? _apiSecret;
  bool _isConfigured = false;

  bool get isConfigured => _isConfigured;
  String? get baseUrl => _baseUrl;

  // Singleton
  static final ErpService _instance = ErpService._internal();
  factory ErpService() => _instance;
  ErpService._internal();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_keyUrl);
    _apiKey = prefs.getString(_keyApiKey);
    _apiSecret = prefs.getString(_keyApiSecret);
    _isConfigured = _baseUrl != null && _baseUrl!.isNotEmpty;
  }

  Future<void> saveConfig({
    required String url,
    required String apiKey,
    required String apiSecret,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUrl, url);
    await prefs.setString(_keyApiKey, apiKey);
    await prefs.setString(_keyApiSecret, apiSecret);

    _baseUrl = url;
    _apiKey = apiKey;
    _apiSecret = apiSecret;
    _isConfigured = url.isNotEmpty;
  }

  Future<void> clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUrl);
    await prefs.remove(_keyApiKey);
    await prefs.remove(_keyApiSecret);

    _baseUrl = null;
    _apiKey = null;
    _apiSecret = null;
    _isConfigured = false;
  }

  Map<String, String> get _headers => {
        'Authorization': 'token $_apiKey:$_apiSecret',
        'Content-Type': 'application/json',
      };

  Future<ErpResult<bool>> testConnection() async {
    if (!_isConfigured) {
      return ErpResult.error('ERPNext belum dikonfigurasi');
    }

    try {
      final url = Uri.parse('$_baseUrl/api/method/frappe.auth.get_logged_user');
      final response = await http.get(url, headers: _headers).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        return ErpResult.success(true);
      } else {
        return ErpResult.error('Gagal terhubung: ${response.statusCode}');
      }
    } catch (e) {
      return ErpResult.error('Error: ${e.toString()}');
    }
  }

  Future<ErpResult<List<ErpProduct>>> getProducts() async {
    if (!_isConfigured) {
      return ErpResult.error('ERPNext belum dikonfigurasi');
    }

    try {
      final url = Uri.parse(
        '$_baseUrl/api/resource/Item?filters=[["disabled","=",0],["is_sales_item","=",1]]&fields=["item_code","item_name","standard_rate","item_group"]&limit_page_length=100',
      );

      final response = await http.get(url, headers: _headers).timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = (data['data'] as List).map((item) {
          return ErpProduct(
            itemCode: item['item_code'] ?? '',
            name: item['item_name'] ?? '',
            price: (item['standard_rate'] ?? 0).toDouble(),
            category: item['item_group'] ?? 'Uncategorized',
          );
        }).toList();

        return ErpResult.success(items);
      } else {
        return ErpResult.error('Gagal mengambil produk: ${response.statusCode}');
      }
    } catch (e) {
      return ErpResult.error('Error: ${e.toString()}');
    }
  }

  Future<ErpResult<String>> createPosInvoice({
    required List<PosItem> items,
    required String customer,
    required String paymentMode,
  }) async {
    if (!_isConfigured) {
      return ErpResult.error('ERPNext belum dikonfigurasi');
    }

    try {
      final url = Uri.parse('$_baseUrl/api/resource/POS Invoice');

      final payload = {
        'customer': customer,
        'is_pos': 1,
        'pos_profile': 'Default POS Profile',
        'items': items
            .map((item) => {
                  'item_code': item.itemCode,
                  'qty': item.qty,
                  'rate': item.rate,
                })
            .toList(),
        'payments': [
          {
            'mode_of_payment': paymentMode,
            'amount': items.fold(0.0, (sum, item) => sum + (item.qty * item.rate)),
          }
        ],
      };

      final response = await http
          .post(
            url,
            headers: _headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final invoiceName = data['data']['name'] ?? 'Unknown';
        return ErpResult.success(invoiceName);
      } else {
        final error = jsonDecode(response.body);
        return ErpResult.error(
          'Gagal membuat invoice: ${error['exc_type'] ?? response.statusCode}',
        );
      }
    } catch (e) {
      return ErpResult.error('Error: ${e.toString()}');
    }
  }

  Future<ErpResult<List<String>>> getCustomers() async {
    if (!_isConfigured) {
      return ErpResult.error('ERPNext belum dikonfigurasi');
    }

    try {
      final url = Uri.parse(
        '$_baseUrl/api/resource/Customer?fields=["name"]&limit_page_length=50',
      );

      final response = await http.get(url, headers: _headers).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final customers = (data['data'] as List)
            .map<String>((c) => c['name'] as String)
            .toList();

        return ErpResult.success(customers);
      } else {
        return ErpResult.error('Gagal mengambil customer: ${response.statusCode}');
      }
    } catch (e) {
      return ErpResult.error('Error: ${e.toString()}');
    }
  }
}

class ErpResult<T> {
  final T? data;
  final String? errorMessage;
  final bool isSuccess;

  ErpResult._({this.data, this.errorMessage, required this.isSuccess});

  factory ErpResult.success(T data) => ErpResult._(data: data, isSuccess: true);
  factory ErpResult.error(String message) =>
      ErpResult._(errorMessage: message, isSuccess: false);
}

class ErpProduct {
  final String itemCode;
  final String name;
  final double price;
  final String category;

  ErpProduct({
    required this.itemCode,
    required this.name,
    required this.price,
    required this.category,
  });
}

class PosItem {
  final String itemCode;
  final int qty;
  final double rate;

  PosItem({
    required this.itemCode,
    required this.qty,
    required this.rate,
  });
}
