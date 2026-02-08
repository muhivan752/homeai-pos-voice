import 'dart:async';
import '../db/local_db.dart';
import '../core/erp_client.dart';

enum SyncMode { auto, manual }

class SyncEngine {
  final LocalDB db;
  final ERPClient erp;
  Timer? _autoSyncTimer;
  bool _isSyncing = false;

  SyncEngine({required this.db, required this.erp});

  // --- Auto Sync ---

  void startAutoSync({Duration interval = const Duration(seconds: 30)}) {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(interval, (_) => syncPending());
    print('[SYNC] Auto-sync dimulai (interval: ${interval.inSeconds}s)');
  }

  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
    print('[SYNC] Auto-sync dihentikan');
  }

  bool get isAutoSyncRunning => _autoSyncTimer != null;

  // --- Manual Sync ---

  Future<SyncResult> syncAll() async {
    final pending = db.pendingTransactions;
    final failed = db.failedTransactions;
    final all = [...pending, ...failed];

    if (all.isEmpty) {
      return SyncResult(total: 0, synced: 0, failed: 0);
    }

    return _syncRecords(all);
  }

  Future<SyncResult> syncPending() async {
    if (_isSyncing) {
      return SyncResult(total: 0, synced: 0, failed: 0, skipped: true);
    }

    final pending = db.pendingTransactions;
    if (pending.isEmpty) return SyncResult(total: 0, synced: 0, failed: 0);

    return _syncRecords(pending);
  }

  Future<SyncResult> _syncRecords(List<TransactionRecord> records) async {
    _isSyncing = true;
    int synced = 0;
    int failed = 0;

    print('[SYNC] Mulai sinkronisasi ${records.length} transaksi...');

    for (final record in records) {
      try {
        await _syncToERP(record);
        await db.markSynced(record.id);
        synced++;
        print('[SYNC] OK: ${record.id} (${record.type})');
      } catch (e) {
        await db.markFailed(record.id, e.toString());
        failed++;
        print('[SYNC] GAGAL: ${record.id} - $e');
      }
    }

    _isSyncing = false;

    final result = SyncResult(
      total: records.length,
      synced: synced,
      failed: failed,
    );
    print('[SYNC] Selesai: $synced berhasil, $failed gagal dari ${records.length} total');
    return result;
  }

  Future<void> _syncToERP(TransactionRecord record) async {
    switch (record.type) {
      case 'sellItem':
        // Individual sell items are batched in checkout
        await db.markSynced(record.id);
        break;

      case 'checkout':
        final items = record.data['items'] as List<dynamic>? ?? [];
        final paymentMethod = record.data['paymentMethod'] as String? ?? 'Cash';

        for (final item in items) {
          await erp.createSalesInvoice(
            itemCode: item['item'] as String,
            qty: item['qty'] as int,
          );
        }
        break;

      case 'cancelItem':
        // Cancel operations are local-only for now
        break;

      default:
        print('[SYNC] Tipe transaksi tidak dikenali: ${record.type}');
    }
  }

  // --- Stock Sync (pull from ERP) ---

  Future<void> syncStock() async {
    try {
      final stock = await erp.getStock();
      db.updateStock(stock);
      print('[SYNC] Stok berhasil disinkronkan');
    } catch (e) {
      print('[SYNC] Gagal sinkron stok: $e');
    }
  }

  // --- Status ---

  Map<String, dynamic> getStatus() {
    return {
      'autoSync': isAutoSyncRunning,
      'isSyncing': _isSyncing,
      'pendingCount': db.pendingTransactions.length,
      'failedCount': db.failedTransactions.length,
    };
  }
}

class SyncResult {
  final int total;
  final int synced;
  final int failed;
  final bool skipped;

  SyncResult({
    required this.total,
    required this.synced,
    required this.failed,
    this.skipped = false,
  });

  @override
  String toString() {
    if (skipped) return 'Sync sedang berjalan, dilewati';
    if (total == 0) return 'Tidak ada transaksi untuk disinkronkan';
    return 'Sync selesai: $synced/$total berhasil, $failed gagal';
  }
}
