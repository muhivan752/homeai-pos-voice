import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/database_helper.dart';
import 'erp_service.dart';

enum SyncStatus {
  idle,
  syncing,
  offline,
  error,
}

class SyncService extends ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final DatabaseHelper _db = DatabaseHelper();
  final ErpService _erp = ErpService();
  final Connectivity _connectivity = Connectivity();

  SyncStatus _status = SyncStatus.idle;
  int _pendingCount = 0;
  String? _lastError;
  bool _isOnline = true;
  Timer? _syncTimer;
  StreamSubscription? _connectivitySubscription;

  SyncStatus get status => _status;
  int get pendingCount => _pendingCount;
  String? get lastError => _lastError;
  bool get isOnline => _isOnline;
  bool get hasPending => _pendingCount > 0;

  Future<void> init() async {
    await _erp.init();
    await _updatePendingCount();
    _startConnectivityMonitor();
    _startPeriodicSync();
  }

  void _startConnectivityMonitor() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      final wasOffline = !_isOnline;
      _isOnline = result != ConnectivityResult.none;

      if (_isOnline && wasOffline) {
        // Back online - trigger sync
        syncNow();
      }

      _status = _isOnline ? SyncStatus.idle : SyncStatus.offline;
      notifyListeners();
    });
  }

  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (_isOnline && _pendingCount > 0) {
        syncNow();
      }
    });
  }

  Future<void> _updatePendingCount() async {
    _pendingCount = await _db.getPendingSyncCount();
    notifyListeners();
  }

  Future<void> syncNow() async {
    if (_status == SyncStatus.syncing) return;
    if (!_isOnline) {
      _status = SyncStatus.offline;
      notifyListeners();
      return;
    }
    if (!_erp.isConfigured) return;

    _status = SyncStatus.syncing;
    _lastError = null;
    notifyListeners();

    try {
      await _syncPendingTransactions();
      _status = SyncStatus.idle;
    } catch (e) {
      _status = SyncStatus.error;
      _lastError = e.toString();
    }

    await _updatePendingCount();
    notifyListeners();
  }

  Future<void> _syncPendingTransactions() async {
    final pending = await _db.getTransactions(syncStatus: 'pending', limit: 10);

    for (final transaction in pending) {
      try {
        final items = await _db.getTransactionItems(transaction['id']);

        final posItems = items.map((item) => PosItem(
          itemCode: item['product_id'],
          qty: item['quantity'],
          rate: item['price'],
        )).toList();

        final result = await _erp.createPosInvoice(
          items: posItems,
          customer: transaction['customer_name'] ?? 'Walk-in Customer',
          paymentMode: transaction['payment_method'] ?? 'Cash',
        );

        if (result.isSuccess) {
          await _db.updateTransactionSyncStatus(
            transaction['id'],
            syncStatus: 'synced',
            erpInvoiceId: result.data,
          );
        } else {
          await _db.updateTransactionSyncStatus(
            transaction['id'],
            syncStatus: 'failed',
            syncError: result.errorMessage,
          );

          // Add to retry queue
          await _addToRetryQueue(transaction['id'], result.errorMessage);
        }
      } catch (e) {
        await _db.updateTransactionSyncStatus(
          transaction['id'],
          syncStatus: 'failed',
          syncError: e.toString(),
        );
      }
    }
  }

  Future<void> _addToRetryQueue(String transactionId, String? error) async {
    final retryAt = DateTime.now().add(const Duration(minutes: 5));

    await _db.addToSyncQueue({
      'entity_type': 'transaction',
      'entity_id': transactionId,
      'action': 'create_invoice',
      'last_error': error,
      'next_retry_at': retryAt.toIso8601String(),
    });
  }

  Future<SyncResult> syncProducts() async {
    if (!_isOnline) {
      return SyncResult(success: false, message: 'Tidak ada koneksi internet');
    }
    if (!_erp.isConfigured) {
      return SyncResult(success: false, message: 'ERPNext belum dikonfigurasi');
    }

    _status = SyncStatus.syncing;
    notifyListeners();

    try {
      final result = await _erp.getProducts();

      if (result.isSuccess && result.data != null) {
        final products = result.data!.map((p) => {
          'id': p.itemCode,
          'item_code': p.itemCode,
          'name': p.name,
          'price': p.price,
          'category': p.category,
          'aliases': p.name.toLowerCase(),
          'is_active': 1,
          'synced_at': DateTime.now().toIso8601String(),
        }).toList();

        await _db.clearProducts();
        final count = await _db.insertProducts(products);

        _status = SyncStatus.idle;
        notifyListeners();

        return SyncResult(
          success: true,
          message: 'Berhasil sync $count produk',
          count: count,
        );
      } else {
        _status = SyncStatus.error;
        _lastError = result.errorMessage;
        notifyListeners();

        return SyncResult(
          success: false,
          message: result.errorMessage ?? 'Gagal mengambil produk',
        );
      }
    } catch (e) {
      _status = SyncStatus.error;
      _lastError = e.toString();
      notifyListeners();

      return SyncResult(success: false, message: e.toString());
    }
  }

  Future<void> retryFailed() async {
    // Reset failed transactions to pending
    final failed = await _db.getTransactions(syncStatus: 'failed', limit: 50);

    for (final transaction in failed) {
      await _db.updateTransactionSyncStatus(
        transaction['id'],
        syncStatus: 'pending',
      );
    }

    await _updatePendingCount();
    await syncNow();
  }

  void dispose() {
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
  }
}

class SyncResult {
  final bool success;
  final String message;
  final int? count;

  SyncResult({
    required this.success,
    required this.message,
    this.count,
  });
}
