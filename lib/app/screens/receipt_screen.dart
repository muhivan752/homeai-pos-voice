import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';

/// Struk digital — styled like a thermal receipt.
/// Can be opened after checkout (with transactionId) or from history.
class ReceiptScreen extends StatefulWidget {
  final String transactionId;

  /// If true, show "Selesai" button to go back to POS (post-checkout mode).
  /// If false, show normal back button (viewing from history).
  final bool isPostCheckout;

  const ReceiptScreen({
    super.key,
    required this.transactionId,
    this.isPostCheckout = false,
  });

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final DatabaseHelper _db = DatabaseHelper();

  Map<String, dynamic>? _transaction;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
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

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        title: const Text('Struk'),
        centerTitle: true,
        automaticallyImplyLeading: !widget.isPostCheckout,
        leading: widget.isPostCheckout ? const SizedBox.shrink() : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transaction == null
              ? const Center(child: Text('Transaksi tidak ditemukan'))
              : Column(
                  children: [
                    // Receipt card
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: _ReceiptCard(
                          transaction: _transaction!,
                          items: _items,
                          formatCurrency: _formatCurrency,
                        ),
                      ),
                    ),

                    // Bottom actions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Share & Copy row
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
                                const SizedBox(width: 12),
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
                            if (widget.isPostCheckout) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.check_circle),
                                  label: const Text(
                                    'SELESAI',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  String _generateReceiptText() {
    if (_transaction == null) return '';

    final tx = _transaction!;
    final subtotal = (tx['subtotal'] ?? tx['total'] ?? 0).toDouble();
    final taxPb1 = (tx['tax_pb1'] ?? 0).toDouble();
    final taxPpn = (tx['tax_ppn'] ?? 0).toDouble();
    final total = (tx['total'] ?? 0).toDouble();
    final createdAt = DateTime.tryParse(tx['created_at'] ?? '');
    final customerName = tx['customer_name'] ?? 'Walk-in Customer';
    final paymentMethod = tx['payment_method'] ?? 'Cash';
    final paymentAmount = (tx['payment_amount'] ?? total).toDouble();
    final changeAmount = (tx['change_amount'] ?? 0).toDouble();
    final cashierName = tx['cashier_name'];

    final buf = StringBuffer();
    buf.writeln('================================');
    buf.writeln('       HOMEAI POS VOICE');
    buf.writeln('================================');
    buf.writeln('');
    if (createdAt != null) {
      buf.writeln('Tanggal : ${DateFormat('dd/MM/yyyy').format(createdAt)}');
      buf.writeln('Jam     : ${DateFormat('HH:mm').format(createdAt)}');
    }
    buf.writeln('Customer: $customerName');
    if (cashierName != null && cashierName.toString().isNotEmpty) {
      buf.writeln('Kasir   : $cashierName');
    }
    buf.writeln('--------------------------------');

    for (final item in _items) {
      final name = item['product_name'] ?? '-';
      final qty = item['quantity'] ?? 0;
      final price = (item['price'] ?? 0).toDouble();
      final itemSub = (item['subtotal'] ?? 0).toDouble();
      buf.writeln('$name');
      buf.writeln('  $qty x Rp ${_formatCurrency(price)}');
      buf.writeln('${' ' * 20}Rp ${_formatCurrency(itemSub)}');
    }

    buf.writeln('--------------------------------');
    final hasTax = taxPb1 > 0 || taxPpn > 0;
    if (hasTax) {
      buf.writeln('Subtotal      Rp ${_formatCurrency(subtotal)}');
      if (taxPb1 > 0) {
        buf.writeln('PB1           Rp ${_formatCurrency(taxPb1)}');
      }
      if (taxPpn > 0) {
        buf.writeln('PPN           Rp ${_formatCurrency(taxPpn)}');
      }
      buf.writeln('--------------------------------');
    }
    buf.writeln('TOTAL         Rp ${_formatCurrency(total)}');
    buf.writeln('');
    buf.writeln('Bayar ($paymentMethod)');
    buf.writeln('              Rp ${_formatCurrency(paymentAmount)}');
    if (changeAmount > 0) {
      buf.writeln('Kembali       Rp ${_formatCurrency(changeAmount)}');
    }
    buf.writeln('');
    buf.writeln('================================');
    buf.writeln('       Terima kasih!');
    buf.writeln('================================');

    return buf.toString();
  }

  void _shareReceipt() {
    Share.share(_generateReceiptText(), subject: 'Struk Pembayaran');
  }

  void _copyReceipt() {
    Clipboard.setData(ClipboardData(text: _generateReceiptText()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Struk disalin ke clipboard'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// The receipt card widget — looks like a thermal receipt.
class _ReceiptCard extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final List<Map<String, dynamic>> items;
  final String Function(double) formatCurrency;

  const _ReceiptCard({
    required this.transaction,
    required this.items,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final subtotal = (transaction['subtotal'] ?? transaction['total'] ?? 0).toDouble();
    final taxPb1 = (transaction['tax_pb1'] ?? 0).toDouble();
    final taxPpn = (transaction['tax_ppn'] ?? 0).toDouble();
    final total = (transaction['total'] ?? 0).toDouble();
    final createdAt = DateTime.tryParse(transaction['created_at'] ?? '');
    final customerName = transaction['customer_name'] ?? 'Walk-in Customer';
    final paymentMethod = transaction['payment_method'] ?? 'Cash';
    final paymentAmount = (transaction['payment_amount'] ?? total).toDouble();
    final changeAmount = (transaction['change_amount'] ?? 0).toDouble();
    final cashierName = transaction['cashier_name'];
    final hasTax = taxPb1 > 0 || taxPpn > 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Zigzag top edge
          CustomPaint(
            size: const Size(double.infinity, 12),
            painter: _ZigzagPainter(isTop: true),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                // Store header
                const Icon(Icons.mic, size: 32, color: Colors.brown),
                const SizedBox(height: 4),
                const Text(
                  'HOMEAI POS VOICE',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  createdAt != null
                      ? DateFormat('dd MMMM yyyy, HH:mm').format(createdAt)
                      : '-',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),

                const SizedBox(height: 12),
                _DashedDivider(),
                const SizedBox(height: 8),

                // Customer & cashier info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Customer',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    Text(
                      customerName,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                if (cashierName != null && cashierName.toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kasir',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      Text(
                        cashierName.toString(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 8),
                _DashedDivider(),
                const SizedBox(height: 12),

                // Items
                for (final item in items) ...[
                  _ReceiptItemRow(item: item, formatCurrency: formatCurrency),
                  const SizedBox(height: 8),
                ],

                const SizedBox(height: 4),
                _DashedDivider(),
                const SizedBox(height: 12),

                // Subtotal (always show if tax present)
                if (hasTax) ...[
                  _ReceiptLine(
                    label: 'Subtotal',
                    value: 'Rp ${formatCurrency(subtotal)}',
                  ),
                  if (taxPb1 > 0) ...[
                    const SizedBox(height: 4),
                    _ReceiptLine(
                      label: 'PB1',
                      value: 'Rp ${formatCurrency(taxPb1)}',
                      valueColor: Colors.grey.shade700,
                    ),
                  ],
                  if (taxPpn > 0) ...[
                    const SizedBox(height: 4),
                    _ReceiptLine(
                      label: 'PPN',
                      value: 'Rp ${formatCurrency(taxPpn)}',
                      valueColor: Colors.grey.shade700,
                    ),
                  ],
                  const SizedBox(height: 8),
                  _DashedDivider(),
                  const SizedBox(height: 12),
                ],

                // Grand Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Rp ${formatCurrency(total)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                _DashedDivider(),
                const SizedBox(height: 12),

                // Payment info
                _ReceiptLine(
                  label: 'Bayar (${_paymentLabel(paymentMethod)})',
                  value: 'Rp ${formatCurrency(paymentAmount)}',
                ),
                if (changeAmount > 0) ...[
                  const SizedBox(height: 4),
                  _ReceiptLine(
                    label: 'Kembali',
                    value: 'Rp ${formatCurrency(changeAmount)}',
                    valueColor: Colors.green.shade700,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                _DashedDivider(),
                const SizedBox(height: 16),

                // Footer
                Text(
                  'Terima kasih!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Powered by HomeAI POS Voice',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),

          // Zigzag bottom edge
          CustomPaint(
            size: const Size(double.infinity, 12),
            painter: _ZigzagPainter(isTop: false),
          ),
        ],
      ),
    );
  }

  String _paymentLabel(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Tunai';
      case 'qris':
        return 'QRIS';
      case 'transfer':
        return 'Transfer';
      case 'card':
        return 'Kartu';
      default:
        return method;
    }
  }
}

class _ReceiptItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final String Function(double) formatCurrency;

  const _ReceiptItemRow({
    required this.item,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final name = item['product_name'] ?? '-';
    final qty = item['quantity'] ?? 0;
    final price = (item['price'] ?? 0).toDouble();
    final subtotal = (item['subtotal'] ?? 0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '  $qty x Rp ${formatCurrency(price)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              'Rp ${formatCurrency(subtotal)}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReceiptLine extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final TextStyle? labelStyle;

  const _ReceiptLine({
    required this.label,
    required this.value,
    this.valueColor,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: labelStyle ?? TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

/// Dashed divider line for receipt styling.
class _DashedDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 5.0;
        const dashSpace = 3.0;
        final dashCount = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.grey.shade400),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Zigzag edge painter for receipt top/bottom.
class _ZigzagPainter extends CustomPainter {
  final bool isTop;

  _ZigzagPainter({required this.isTop});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    const zigzagWidth = 10.0;
    final zigzagHeight = size.height;

    if (isTop) {
      path.moveTo(0, zigzagHeight);
      for (double x = 0; x < size.width; x += zigzagWidth) {
        path.lineTo(x + zigzagWidth / 2, 0);
        path.lineTo(x + zigzagWidth, zigzagHeight);
      }
      path.lineTo(size.width, zigzagHeight);
      path.close();
    } else {
      path.moveTo(0, 0);
      for (double x = 0; x < size.width; x += zigzagWidth) {
        path.lineTo(x + zigzagWidth / 2, zigzagHeight);
        path.lineTo(x + zigzagWidth, 0);
      }
      path.lineTo(size.width, 0);
      path.close();
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
