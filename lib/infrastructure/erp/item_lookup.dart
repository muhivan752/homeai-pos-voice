import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'erpnext_config.dart';

/// Lookup item_code dari ERPNext berdasarkan item_name.
/// Cache in-memory untuk performa.
class ItemLookup {
  final ERPNextConfig config;
  final http.Client _client;

  /// Cache: item_name (lowercase) → item_code
  final Map<String, String> _cache = {};

  static const _timeout = Duration(seconds: 10);

  ItemLookup(this.config, {http.Client? client})
      : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'Authorization': 'token ${config.apiKey}:${config.apiSecret}',
        'Content-Type': 'application/json',
      };

  /// Cari item_code dari ERPNext berdasarkan nama item.
  /// Returns item_code jika ditemukan, null jika tidak.
  Future<String?> lookup(String itemName) async {
    final key = itemName.toLowerCase().trim();

    // Check cache dulu
    if (_cache.containsKey(key)) {
      return _cache[key];
    }

    // Query ERPNext
    try {
      final itemCode = await _queryItem(key);
      if (itemCode != null) {
        _cache[key] = itemCode;
      }
      return itemCode;
    } on TimeoutException {
      return null;
    } on SocketException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Cari item_code, fallback ke naive mapping jika tidak ditemukan.
  Future<String> lookupOrFallback(String itemName) async {
    final itemCode = await lookup(itemName);
    return itemCode ?? _naiveFallback(itemName);
  }

  Future<String?> _queryItem(String itemName) async {
    // Coba exact match dulu
    var itemCode = await _queryByFilter('item_name', itemName);
    if (itemCode != null) return itemCode;

    // Coba dengan capitalized
    final capitalized = _capitalize(itemName);
    itemCode = await _queryByFilter('item_name', capitalized);
    if (itemCode != null) return itemCode;

    // Coba cari dengan LIKE
    itemCode = await _queryByLike(itemName);
    return itemCode;
  }

  Future<String?> _queryByFilter(String field, String value) async {
    final filters = jsonEncode([
      [field, '=', value]
    ]);
    final url = Uri.parse(
      '${config.baseUrl}/api/resource/Item?filters=$filters&fields=["item_code"]&limit_page_length=1',
    );

    final res = await _client.get(url, headers: _headers).timeout(_timeout);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final items = data['data'] as List?;
      if (items != null && items.isNotEmpty) {
        return items[0]['item_code'] as String?;
      }
    }
    return null;
  }

  Future<String?> _queryByLike(String itemName) async {
    final filters = jsonEncode([
      ['item_name', 'like', '%$itemName%']
    ]);
    final url = Uri.parse(
      '${config.baseUrl}/api/resource/Item?filters=$filters&fields=["item_code"]&limit_page_length=1',
    );

    final res = await _client.get(url, headers: _headers).timeout(_timeout);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final items = data['data'] as List?;
      if (items != null && items.isNotEmpty) {
        return items[0]['item_code'] as String?;
      }
    }
    return null;
  }

  String _capitalize(String s) {
    return s.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  String _naiveFallback(String item) {
    return item.toLowerCase().replaceAll(' ', '_');
  }

  /// Clear cache (untuk testing)
  void clearCache() => _cache.clear();
}
