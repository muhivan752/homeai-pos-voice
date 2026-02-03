import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Debug script untuk cek koneksi ERPNext dan items
void main() async {
  print('=== ERPNext Debug ===\n');

  // Load config from env
  final baseUrl = Platform.environment['ERP_BASE_URL'] ?? '';
  final apiKey = Platform.environment['ERP_API_KEY'] ?? '';
  final apiSecret = Platform.environment['ERP_API_SECRET'] ?? '';
  final warehouse = Platform.environment['ERP_WAREHOUSE'] ?? '';
  final posProfile = Platform.environment['ERP_POS_PROFILE'] ?? '';

  print('Config:');
  print('  BASE_URL: $baseUrl');
  print('  API_KEY: ${apiKey.substring(0, 5)}...');
  print('  WAREHOUSE: $warehouse');
  print('  POS_PROFILE: $posProfile');
  print('');

  final headers = {
    'Authorization': 'token $apiKey:$apiSecret',
    'Content-Type': 'application/json',
  };

  // Test 1: Connection
  print('--- Test 1: Connection ---');
  try {
    final res = await http.get(
      Uri.parse('$baseUrl/api/method/frappe.ping'),
      headers: headers,
    );
    print('Status: ${res.statusCode}');
    print('Response: ${res.body}');
  } catch (e) {
    print('ERROR: $e');
  }
  print('');

  // Test 2: List all Items
  print('--- Test 2: List Items ---');
  try {
    final res = await http.get(
      Uri.parse('$baseUrl/api/resource/Item?fields=["item_code","item_name"]&limit_page_length=20'),
      headers: headers,
    );
    print('Status: ${res.statusCode}');
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final items = data['data'] as List;
      print('Found ${items.length} items:');
      for (final item in items) {
        print('  - item_code: "${item['item_code']}", item_name: "${item['item_name']}"');
      }
    } else {
      print('Response: ${res.body}');
    }
  } catch (e) {
    print('ERROR: $e');
  }
  print('');

  // Test 3: Search for "kopi"
  print('--- Test 3: Search "kopi" ---');
  try {
    final filters = jsonEncode([
      ['item_name', 'like', '%kopi%']
    ]);
    final res = await http.get(
      Uri.parse('$baseUrl/api/resource/Item?filters=$filters&fields=["item_code","item_name"]'),
      headers: headers,
    );
    print('Status: ${res.statusCode}');
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final items = data['data'] as List;
      print('Found ${items.length} items matching "kopi":');
      for (final item in items) {
        print('  - item_code: "${item['item_code']}", item_name: "${item['item_name']}"');
      }
    } else {
      print('Response: ${res.body}');
    }
  } catch (e) {
    print('ERROR: $e');
  }
  print('');

  // Test 4: Check Warehouse
  print('--- Test 4: Check Warehouse ---');
  try {
    final res = await http.get(
      Uri.parse('$baseUrl/api/resource/Warehouse?filters=[["name","=","$warehouse"]]'),
      headers: headers,
    );
    print('Status: ${res.statusCode}');
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final items = data['data'] as List;
      if (items.isEmpty) {
        print('WARNING: Warehouse "$warehouse" tidak ditemukan!');
      } else {
        print('Warehouse OK: $warehouse');
      }
    }
  } catch (e) {
    print('ERROR: $e');
  }
  print('');

  // Test 5: Check Stock for items
  print('--- Test 5: Check Stock ---');
  try {
    final res = await http.get(
      Uri.parse('$baseUrl/api/resource/Bin?filters=[["warehouse","=","$warehouse"]]&fields=["item_code","actual_qty"]&limit_page_length=20'),
      headers: headers,
    );
    print('Status: ${res.statusCode}');
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final bins = data['data'] as List;
      print('Stock in "$warehouse":');
      for (final bin in bins) {
        print('  - ${bin['item_code']}: ${bin['actual_qty']}');
      }
      if (bins.isEmpty) {
        print('  (tidak ada stock)');
      }
    }
  } catch (e) {
    print('ERROR: $e');
  }
  print('');

  // Test 6: Try create POS Invoice
  print('--- Test 6: Create Test Invoice ---');
  try {
    // First get an item_code that exists
    final itemRes = await http.get(
      Uri.parse('$baseUrl/api/resource/Item?limit_page_length=1&fields=["item_code"]'),
      headers: headers,
    );

    if (itemRes.statusCode == 200) {
      final itemData = jsonDecode(itemRes.body);
      final items = itemData['data'] as List;
      if (items.isNotEmpty) {
        final testItemCode = items[0]['item_code'];
        print('Using item_code: $testItemCode');

        final body = {
          'doctype': 'POS Invoice',
          'customer': 'Walk-in Customer',
          'pos_profile': posProfile,
          'items': [
            {
              'item_code': testItemCode,
              'qty': 1,
              'warehouse': warehouse,
            }
          ],
        };

        final res = await http.post(
          Uri.parse('$baseUrl/api/resource/POS Invoice'),
          headers: headers,
          body: jsonEncode(body),
        );
        print('Status: ${res.statusCode}');
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = jsonDecode(res.body);
          print('SUCCESS! Invoice created: ${data['data']?['name']}');

          // Delete the test invoice
          final invoiceName = data['data']?['name'];
          if (invoiceName != null) {
            await http.delete(
              Uri.parse('$baseUrl/api/resource/POS Invoice/$invoiceName'),
              headers: headers,
            );
            print('Test invoice deleted.');
          }
        } else {
          print('FAILED: ${res.body}');
        }
      }
    }
  } catch (e) {
    print('ERROR: $e');
  }

  print('\n=== Debug selesai ===');
}
