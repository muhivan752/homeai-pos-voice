import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Debug script untuk cek EXACT values di ERPNext
void main() async {
  print('=== ERPNext Exact Value Debug ===\n');

  final baseUrl = Platform.environment['ERP_BASE_URL'] ?? '';
  final apiKey = Platform.environment['ERP_API_KEY'] ?? '';
  final apiSecret = Platform.environment['ERP_API_SECRET'] ?? '';
  final warehouse = Platform.environment['ERP_WAREHOUSE'] ?? '';

  final headers = {
    'Authorization': 'token $apiKey:$apiSecret',
    'Content-Type': 'application/json',
  };

  print('ENV WAREHOUSE: "$warehouse"');
  print('ENV WAREHOUSE bytes: ${warehouse.codeUnits}');
  print('');

  // Get ALL warehouses
  print('--- All Warehouses in ERPNext ---');
  try {
    final res = await http.get(
      Uri.parse('$baseUrl/api/resource/Warehouse?fields=["name"]&limit_page_length=50'),
      headers: headers,
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final warehouses = data['data'] as List;

      for (final wh in warehouses) {
        final name = wh['name'] as String;
        print('  Name: "$name"');
        print('  Bytes: ${name.codeUnits}');

        if (name.toLowerCase().contains('main')) {
          print('  ^^^ This contains "main" ^^^');
          if (name == warehouse) {
            print('  ✓ EXACT MATCH with ENV!');
          } else {
            print('  ✗ NOT exact match with ENV');
            print('  Difference:');
            for (var i = 0; i < name.length || i < warehouse.length; i++) {
              final envChar = i < warehouse.length ? warehouse.codeUnitAt(i) : -1;
              final erpChar = i < name.length ? name.codeUnitAt(i) : -1;
              if (envChar != erpChar) {
                print('    Position $i: ENV=${envChar} (${i < warehouse.length ? warehouse[i] : "N/A"}) vs ERP=${erpChar} (${i < name.length ? name[i] : "N/A"})');
              }
            }
          }
        }
        print('');
      }
    }
  } catch (e) {
    print('ERROR: $e');
  }

  // Get ALL items
  print('--- All Items in ERPNext ---');
  try {
    final res = await http.get(
      Uri.parse('$baseUrl/api/resource/Item?fields=["item_code","item_name"]&limit_page_length=50'),
      headers: headers,
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final items = data['data'] as List;

      for (final item in items) {
        print('  item_code: "${item['item_code']}", item_name: "${item['item_name']}"');
      }
    }
  } catch (e) {
    print('ERROR: $e');
  }
  print('');

  // Get stock from Bin
  print('--- Stock in Bin table ---');
  try {
    final res = await http.get(
      Uri.parse('$baseUrl/api/resource/Bin?fields=["item_code","warehouse","actual_qty"]&limit_page_length=50'),
      headers: headers,
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final bins = data['data'] as List;

      if (bins.isEmpty) {
        print('  (No stock entries in Bin table!)');
      }

      for (final bin in bins) {
        final binWarehouse = bin['warehouse'] as String;
        print('  item: "${bin['item_code']}", warehouse: "$binWarehouse", qty: ${bin['actual_qty']}');
        print('    warehouse bytes: ${binWarehouse.codeUnits}');
      }
    }
  } catch (e) {
    print('ERROR: $e');
  }
  print('');

  // Try to create invoice with first item found
  print('--- Test Create Invoice ---');
  try {
    // Get first item
    final itemRes = await http.get(
      Uri.parse('$baseUrl/api/resource/Item?fields=["item_code"]&limit_page_length=1'),
      headers: headers,
    );

    if (itemRes.statusCode == 200) {
      final itemData = jsonDecode(itemRes.body);
      final items = itemData['data'] as List;

      if (items.isNotEmpty) {
        final itemCode = items[0]['item_code'];

        // Get warehouse from Bin (use actual warehouse name from stock)
        final binRes = await http.get(
          Uri.parse('$baseUrl/api/resource/Bin?filters=[["item_code","=","$itemCode"]]&fields=["warehouse"]&limit_page_length=1'),
          headers: headers,
        );

        String? actualWarehouse;
        if (binRes.statusCode == 200) {
          final binData = jsonDecode(binRes.body);
          final bins = binData['data'] as List;
          if (bins.isNotEmpty) {
            actualWarehouse = bins[0]['warehouse'];
          }
        }

        print('Using item_code: $itemCode');
        print('Using warehouse from ENV: $warehouse');
        print('Actual warehouse from Bin: $actualWarehouse');

        // Try with ENV warehouse
        print('\n[Test 1] Create with ENV warehouse...');
        final body1 = {
          'doctype': 'POS Invoice',
          'customer': 'Walk-in Customer',
          'pos_profile': Platform.environment['ERP_POS_PROFILE'] ?? 'POS HAI',
          'items': [
            {
              'item_code': itemCode,
              'qty': 1,
              'warehouse': warehouse,
            }
          ],
        };

        final res1 = await http.post(
          Uri.parse('$baseUrl/api/resource/POS Invoice'),
          headers: headers,
          body: jsonEncode(body1),
        );

        print('Status: ${res1.statusCode}');
        if (res1.statusCode == 200 || res1.statusCode == 201) {
          print('SUCCESS!');
          final data = jsonDecode(res1.body);
          final invoiceName = data['data']?['name'];
          // Delete test invoice
          if (invoiceName != null) {
            await http.delete(
              Uri.parse('$baseUrl/api/resource/POS Invoice/$invoiceName'),
              headers: headers,
            );
            print('Test invoice deleted.');
          }
        } else {
          print('FAILED: ${res1.body}');
        }

        // Try with actual warehouse from Bin
        if (actualWarehouse != null && actualWarehouse != warehouse) {
          print('\n[Test 2] Create with Bin warehouse...');
          final body2 = {
            'doctype': 'POS Invoice',
            'customer': 'Walk-in Customer',
            'pos_profile': Platform.environment['ERP_POS_PROFILE'] ?? 'POS HAI',
            'items': [
              {
                'item_code': itemCode,
                'qty': 1,
                'warehouse': actualWarehouse,
              }
            ],
          };

          final res2 = await http.post(
            Uri.parse('$baseUrl/api/resource/POS Invoice'),
            headers: headers,
            body: jsonEncode(body2),
          );

          print('Status: ${res2.statusCode}');
          if (res2.statusCode == 200 || res2.statusCode == 201) {
            print('SUCCESS with actual warehouse!');
            print('>>> USE THIS WAREHOUSE: "$actualWarehouse"');
            final data = jsonDecode(res2.body);
            final invoiceName = data['data']?['name'];
            if (invoiceName != null) {
              await http.delete(
                Uri.parse('$baseUrl/api/resource/POS Invoice/$invoiceName'),
                headers: headers,
              );
            }
          } else {
            print('FAILED: ${res2.body}');
          }
        }
      }
    }
  } catch (e) {
    print('ERROR: $e');
  }

  print('\n=== Debug selesai ===');
}
