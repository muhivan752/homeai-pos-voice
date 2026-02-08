import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../services/sync_service.dart';
import 'transaction_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  final DatabaseHelper _db = DatabaseHelper();
  final SyncService _syncService = SyncService();
  late TabController _tabController;

  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _pendingTransactions = [];
  bool _isLoading = true;
  Map<String, dynamic>? _todayStats;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final all = await _db.getTransactions(limit: 100);
      final pending = await _db.getTransactions(syncStatus: 'pending');
      final stats = await _db.getTodayStats();

      setState(() {
        _allTransactions = all;
        _pendingTransactions = pending;
        _todayStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sinkronisasi...')),
              );
              await _syncService.syncNow();
              await _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sinkronisasi selesai'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            tooltip: 'Sync sekarang',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.list, size: 18),
                  const SizedBox(width: 6),
                  const Text('Semua'),
                  if (_allTransactions.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _Badge(count: _allTransactions.length),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.pending, size: 18),
                  const SizedBox(width: 6),
                  const Text('Pending'),
                  if (_pendingTransactions.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _Badge(count: _pendingTransactions.length, color: Colors.orange),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Today's Stats
          if (_todayStats != null) _TodayStatsCard(stats: _todayStats!),

          // Transaction List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _TransactionList(
                        transactions: _allTransactions,
                        onRefresh: _loadData,
                        emptyMessage: 'Belum ada transaksi',
                      ),
                      _TransactionList(
                        transactions: _pendingTransactions,
                        onRefresh: _loadData,
                        emptyMessage: 'Tidak ada transaksi pending',
                        showRetryAll: true,
                        onRetryAll: () async {
                          await _syncService.retryFailed();
                          await _loadData();
                        },
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class _TodayStatsCard extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _TodayStatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final count = stats['transaction_count'] ?? 0;
    final total = (stats['total_sales'] ?? 0).toDouble();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Penjualan Hari Ini',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rp ${_formatCurrency(total)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  '$count transaksi',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}

class _TransactionList extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;
  final Future<void> Function() onRefresh;
  final String emptyMessage;
  final bool showRetryAll;
  final VoidCallback? onRetryAll;

  const _TransactionList({
    required this.transactions,
    required this.onRefresh,
    required this.emptyMessage,
    this.showRetryAll = false,
    this.onRetryAll,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Column(
        children: [
          if (showRetryAll && transactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: ElevatedButton.icon(
                onPressed: onRetryAll,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry Semua'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: transactions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final tx = transactions[index];
                return _TransactionCard(
                  transaction: tx,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TransactionDetailScreen(
                          transactionId: tx['id'],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final VoidCallback onTap;

  const _TransactionCard({
    required this.transaction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final total = (transaction['total'] ?? 0).toDouble();
    final syncStatus = transaction['sync_status'] ?? 'pending';
    final createdAt = DateTime.tryParse(transaction['created_at'] ?? '');
    final erpInvoiceId = transaction['erp_invoice_id'];

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (syncStatus) {
      case 'synced':
        statusColor = Colors.green;
        statusIcon = Icons.cloud_done;
        statusText = 'Synced';
        break;
      case 'failed':
        statusColor = Colors.red;
        statusIcon = Icons.cloud_off;
        statusText = 'Failed';
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.cloud_upload;
        statusText = 'Pending';
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Status Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(statusIcon, color: statusColor, size: 24),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Rp ${_formatCurrency(total)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      createdAt != null
                          ? DateFormat('dd MMM yyyy, HH:mm').format(createdAt)
                          : '-',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    if (erpInvoiceId != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Invoice: $erpInvoiceId',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  final Color color;

  const _Badge({required this.count, this.color = Colors.blue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
