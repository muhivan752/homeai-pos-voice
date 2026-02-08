import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

enum SyncStatus { pending, synced, failed }

class TransactionRecord {
  final String id;
  final String type; // sellItem, checkout, cancelItem
  final Map<String, dynamic> data;
  final DateTime createdAt;
  SyncStatus syncStatus;
  String? syncError;
  DateTime? syncedAt;

  TransactionRecord({
    required this.id,
    required this.type,
    required this.data,
    required this.createdAt,
    this.syncStatus = SyncStatus.pending,
    this.syncError,
    this.syncedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'data': data,
        'createdAt': createdAt.toIso8601String(),
        'syncStatus': syncStatus.name,
        'syncError': syncError,
        'syncedAt': syncedAt?.toIso8601String(),
      };

  factory TransactionRecord.fromJson(Map<String, dynamic> json) {
    return TransactionRecord(
      id: json['id'],
      type: json['type'],
      data: Map<String, dynamic>.from(json['data']),
      createdAt: DateTime.parse(json['createdAt']),
      syncStatus: SyncStatus.values.byName(json['syncStatus']),
      syncError: json['syncError'],
      syncedAt: json['syncedAt'] != null ? DateTime.parse(json['syncedAt']) : null,
    );
  }
}

class LocalDB {
  final String dbPath;
  final List<TransactionRecord> _transactions = [];
  final Map<String, int> _stock = {};
  final List<Map<String, dynamic>> _cart = [];

  LocalDB({String? dbPath})
      : dbPath = dbPath ?? p.join(Directory.current.path, '.homeai_db');

  // --- Initialization ---

  Future<void> init() async {
    final dir = Directory(dbPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await _loadTransactions();
    await _loadStock();
  }

  // --- Cart Operations ---

  void addToCart({required String item, required int qty}) {
    final existing = _cart.indexWhere((e) => e['item'] == item);
    if (existing >= 0) {
      _cart[existing]['qty'] = (_cart[existing]['qty'] as int) + qty;
    } else {
      _cart.add({'item': item, 'qty': qty});
    }
  }

  bool removeFromCart({String? item}) {
    if (item != null) {
      final idx = _cart.indexWhere((e) => e['item'] == item);
      if (idx >= 0) {
        _cart.removeAt(idx);
        return true;
      }
      return false;
    }
    if (_cart.isNotEmpty) {
      _cart.removeLast();
      return true;
    }
    return false;
  }

  List<Map<String, dynamic>> get cart => List.unmodifiable(_cart);

  void clearCart() => _cart.clear();

  // --- Transaction Operations ---

  Future<TransactionRecord> addTransaction({
    required String id,
    required String type,
    required Map<String, dynamic> data,
  }) async {
    final record = TransactionRecord(
      id: id,
      type: type,
      data: data,
      createdAt: DateTime.now(),
    );
    _transactions.add(record);
    await _saveTransactions();
    return record;
  }

  List<TransactionRecord> get transactions => List.unmodifiable(_transactions);

  List<TransactionRecord> get pendingTransactions =>
      _transactions.where((t) => t.syncStatus == SyncStatus.pending).toList();

  List<TransactionRecord> get failedTransactions =>
      _transactions.where((t) => t.syncStatus == SyncStatus.failed).toList();

  List<TransactionRecord> get todayTransactions {
    final today = DateTime.now();
    return _transactions
        .where((t) =>
            t.createdAt.year == today.year &&
            t.createdAt.month == today.month &&
            t.createdAt.day == today.day)
        .toList();
  }

  Future<void> markSynced(String id) async {
    final record = _transactions.firstWhere((t) => t.id == id);
    record.syncStatus = SyncStatus.synced;
    record.syncedAt = DateTime.now();
    record.syncError = null;
    await _saveTransactions();
  }

  Future<void> markFailed(String id, String error) async {
    final record = _transactions.firstWhere((t) => t.id == id);
    record.syncStatus = SyncStatus.failed;
    record.syncError = error;
    await _saveTransactions();
  }

  // --- Stock Operations ---

  void updateStock(Map<String, int> stockData) {
    _stock.addAll(stockData);
    _saveStock();
  }

  Map<String, int> getStock({String? item}) {
    if (item != null) {
      final qty = _stock[item];
      if (qty != null) return {item: qty};
      return {};
    }
    return Map.unmodifiable(_stock);
  }

  // --- Report ---

  Map<String, dynamic> getDailyReport() {
    final today = todayTransactions;
    final checkouts = today.where((t) => t.type == 'checkout').toList();
    int totalSales = 0;
    for (final tx in checkouts) {
      totalSales += (tx.data['totalAmount'] as int? ?? 0);
    }

    return {
      'date': DateTime.now().toIso8601String().substring(0, 10),
      'totalTransactions': checkouts.length,
      'totalSales': totalSales,
      'pendingSync': pendingTransactions.length,
      'failedSync': failedTransactions.length,
    };
  }

  // --- Persistence (JSON file-based) ---

  Future<void> _loadTransactions() async {
    final file = File(p.join(dbPath, 'transactions.json'));
    if (await file.exists()) {
      final content = await file.readAsString();
      final list = jsonDecode(content) as List;
      _transactions.clear();
      _transactions.addAll(list.map((e) => TransactionRecord.fromJson(e)));
    }
  }

  Future<void> _saveTransactions() async {
    final file = File(p.join(dbPath, 'transactions.json'));
    final data = _transactions.map((t) => t.toJson()).toList();
    await file.writeAsString(jsonEncode(data));
  }

  Future<void> _loadStock() async {
    final file = File(p.join(dbPath, 'stock.json'));
    if (await file.exists()) {
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      _stock.clear();
      data.forEach((k, v) => _stock[k] = v as int);
    }
  }

  Future<void> _saveStock() async {
    final file = File(p.join(dbPath, 'stock.json'));
    await file.writeAsString(jsonEncode(_stock));
  }
}
