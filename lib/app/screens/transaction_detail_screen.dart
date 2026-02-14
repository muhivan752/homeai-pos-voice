import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';
import '../services/sync_service.dart';
import 'receipt_screen.dart';

class TransactionDetailScreen extends StatefulWidget {
  final String transactionId;

  const TransactionDetailScreen({
    super.key,
    required this.transactionId,
  });

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final SyncService _syncService = SyncService();

  Map<String, dynamic>? _transaction;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final tx = await _db.getTransactionById(widget.transactionId);
      final items = await _db.getTransactionItems(widget.transactionId);

      setState(() {
        _transaction = tx;
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Transaksi')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_transaction == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Transaksi')),
        body: const Center(child: Text('Transaksi tidak ditemukan')),
      );
    }

    final subtotal = (_transaction!['subtotal'] ?? _transaction!['total'] ?? 0).toDouble();
    final taxPb1 = (_transaction!['tax_pb1'] ?? 0).toDouble();
    final taxPpn = (_transaction!['tax_ppn'] ?? 0).toDouble();
    final total = (_transaction!['total'] ?? 0).toDouble();
    final syncStatus = _transaction!['sync_status'] ?? 'pending';
    final createdAt = DateTime.tryParse(_transaction!['created_at'] ?? '');
    final customerName = _transaction!['customer_name'] ?? 'Walk-in Customer';
    final paymentMethod = _transaction!['payment_method'] ?? 'Cash';
    final paymentAmount = (_transaction!['payment_amount'] ?? total).toDouble();
    final changeAmount = (_transaction!['change_amount'] ?? 0).toDouble();
    final erpInvoiceId = _transaction!['erp_invoice_id'];
    final syncError = _transaction!['sync_error'];
    final hasTax = taxPb1 > 0 || taxPpn > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Transaksi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareReceipt(),
            tooltip: 'Share Struk',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Column(
                children: [
                  Text(
                    'Rp ${_formatCurrency(total)}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SyncStatusBadge(status: syncStatus),
                ],
              ),
            ),

            // Transaction Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoCard(
                    children: [
                      _InfoRow(
                        icon: Icons.access_time,
                        label: 'Waktu',
                        value: createdAt != null
                            ? DateFormat('dd MMMM yyyy, HH:mm').format(createdAt)
                            : '-',
                      ),
                      const Divider(),
                      _InfoRow(
                        icon: Icons.person_outline,
                        label: 'Customer',
                        value: customerName,
                      ),
                      const Divider(),
                      _InfoRow(
                        icon: Icons.payment,
                        label: 'Pembayaran',
                        value: paymentMethod,
                      ),
                      if (erpInvoiceId != null) ...[
                        const Divider(),
                        _InfoRow(
                          icon: Icons.receipt,
                          label: 'Invoice ERPNext',
                          value: erpInvoiceId,
                          valueColor: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                      if (syncError != null && syncStatus == 'failed') ...[
                        const Divider(),
                        _InfoRow(
                          icon: Icons.error_outline,
                          label: 'Error',
                          value: syncError,
                          valueColor: Colors.red,
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'Item',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Items List
                  _InfoCard(
                    children: [
                      for (var i = 0; i < _items.length; i++) ...[
                        if (i > 0) const Divider(),
                        _ItemRow(item: _items[i]),
                      ],
                      const Divider(thickness: 2),
                      if (hasTax) ...[
                        _SummaryRow(label: 'Subtotal', amount: subtotal),
                        if (taxPb1 > 0) _SummaryRow(label: 'PB1', amount: taxPb1),
                        if (taxPpn > 0) _SummaryRow(label: 'PPN', amount: taxPpn),
                        const Divider(),
                      ],
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Rp ${_formatCurrency(total)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Payment details
                      if (paymentAmount > 0) ...[
                        const Divider(),
                        _SummaryRow(
                          label: 'Bayar (${paymentMethod})',
                          amount: paymentAmount,
                        ),
                        if (changeAmount > 0)
                          _SummaryRow(
                            label: 'Kembali',
                            amount: changeAmount,
                            color: Colors.green.shade700,
                          ),
                      ],
                    ],
                  ),

                  // Retry Button for failed transactions
                  if (syncStatus == 'failed' || syncStatus == 'pending') ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Mencoba sync ulang...')),
                          );

                          await _db.updateTransactionSyncStatus(
                            widget.transactionId,
                            syncStatus: 'pending',
                          );
                          await _syncService.syncNow();
                          await _loadData();

                          if (mounted) {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          }
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Sync Ulang ke ERPNext'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // View Receipt Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReceiptScreen(
                              transactionId: widget.transactionId,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.receipt),
                      label: const Text('Lihat Struk'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),

                  // Share Receipt Button
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _shareReceipt,
                          icon: const Icon(Icons.share, size: 18),
                          label: const Text('Share'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _copyReceipt,
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('Copy'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _generateReceipt() {
    final tx = _transaction!;
    final itemSubtotal = (tx['subtotal'] ?? tx['total'] ?? 0).toDouble();
    final taxPb1 = (tx['tax_pb1'] ?? 0).toDouble();
    final taxPpn = (tx['tax_ppn'] ?? 0).toDouble();
    final total = (tx['total'] ?? 0).toDouble();
    final createdAt = DateTime.tryParse(tx['created_at'] ?? '');
    final customerName = tx['customer_name'] ?? 'Walk-in Customer';
    final paymentMethod = tx['payment_method'] ?? 'Cash';
    final paymentAmount = (tx['payment_amount'] ?? total).toDouble();
    final changeAmount = (tx['change_amount'] ?? 0).toDouble();

    final buffer = StringBuffer();

    buffer.writeln('================================');
    buffer.writeln('       HOMEAI POS VOICE');
    buffer.writeln('================================');
    buffer.writeln('');
    buffer.writeln('Tanggal: ${createdAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(createdAt) : '-'}');
    buffer.writeln('Customer: $customerName');
    buffer.writeln('--------------------------------');

    for (final item in _items) {
      final name = item['product_name'] ?? '-';
      final qty = item['quantity'] ?? 0;
      final price = (item['price'] ?? 0).toDouble();
      final sub = (item['subtotal'] ?? 0).toDouble();
      buffer.writeln('$name');
      buffer.writeln('  $qty x Rp ${_formatCurrency(price)} = Rp ${_formatCurrency(sub)}');
    }

    buffer.writeln('--------------------------------');
    final hasTax = taxPb1 > 0 || taxPpn > 0;
    if (hasTax) {
      buffer.writeln('Subtotal: Rp ${_formatCurrency(itemSubtotal)}');
      if (taxPb1 > 0) buffer.writeln('PB1:      Rp ${_formatCurrency(taxPb1)}');
      if (taxPpn > 0) buffer.writeln('PPN:      Rp ${_formatCurrency(taxPpn)}');
      buffer.writeln('--------------------------------');
    }
    buffer.writeln('TOTAL:    Rp ${_formatCurrency(total)}');
    buffer.writeln('');
    buffer.writeln('Bayar ($paymentMethod):');
    buffer.writeln('          Rp ${_formatCurrency(paymentAmount)}');
    if (changeAmount > 0) {
      buffer.writeln('Kembali:  Rp ${_formatCurrency(changeAmount)}');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('');
    buffer.writeln('    Terima kasih!');
    buffer.writeln('================================');

    return buffer.toString();
  }

  void _shareReceipt() {
    final receipt = _generateReceipt();
    Share.share(receipt, subject: 'Struk Pembayaran');
  }

  void _copyReceipt() {
    final receipt = _generateReceipt();
    Clipboard.setData(ClipboardData(text: receipt));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Struk disalin ke clipboard'),
        backgroundColor: Colors.green,
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

class _SyncStatusBadge extends StatelessWidget {
  final String status;

  const _SyncStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String text;

    switch (status) {
      case 'synced':
        color = Colors.green;
        icon = Icons.cloud_done;
        text = 'Synced ke ERPNext';
        break;
      case 'failed':
        color = Colors.red;
        icon = Icons.cloud_off;
        text = 'Sync Gagal';
        break;
      default:
        color = Colors.orange;
        icon = Icons.cloud_upload;
        text = 'Menunggu Sync';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final Map<String, dynamic> item;

  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = item['product_name'] ?? '-';
    final qty = item['quantity'] ?? 0;
    final price = (item['price'] ?? 0).toDouble();
    final subtotal = (item['subtotal'] ?? 0).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '$qty x Rp ${_formatCurrency(price)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Rp ${_formatCurrency(subtotal)}',
            style: const TextStyle(fontWeight: FontWeight.w500),
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

class _SummaryRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color? color;

  const _SummaryRow({
    required this.label,
    required this.amount,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            'Rp $formatted',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
