import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';

/// Laporan Penjualan — sales report with date filter, top products, tax summary.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

enum ReportPeriod { today, yesterday, thisWeek, thisMonth, custom }

class _ReportScreenState extends State<ReportScreen> {
  final DatabaseHelper _db = DatabaseHelper();

  ReportPeriod _period = ReportPeriod.today;
  DateTimeRange? _customRange;
  Map<String, dynamic>? _report;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  (String, String) _getDateRange() {
    final now = DateTime.now();
    switch (_period) {
      case ReportPeriod.today:
        final d = _fmt(now);
        return (d, d);
      case ReportPeriod.yesterday:
        final d = _fmt(now.subtract(const Duration(days: 1)));
        return (d, d);
      case ReportPeriod.thisWeek:
        final start = now.subtract(Duration(days: now.weekday - 1));
        return (_fmt(start), _fmt(now));
      case ReportPeriod.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        return (_fmt(start), _fmt(now));
      case ReportPeriod.custom:
        if (_customRange != null) {
          return (_fmt(_customRange!.start), _fmt(_customRange!.end));
        }
        final d = _fmt(now);
        return (d, d);
    }
  }

  String _fmt(DateTime d) => d.toIso8601String().substring(0, 10);

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final (start, end) = _getDateRange();
      final report = await _db.getSalesReport(startDate: start, endDate: end);
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectCustomRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: _customRange ?? DateTimeRange(
        start: now.subtract(const Duration(days: 7)),
        end: now,
      ),
      helpText: 'Pilih rentang tanggal',
      cancelText: 'Batal',
      confirmText: 'OK',
      saveText: 'OK',
    );
    if (range != null) {
      setState(() {
        _period = ReportPeriod.custom;
        _customRange = range;
      });
      _loadReport();
    }
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  String _periodLabel() {
    switch (_period) {
      case ReportPeriod.today:
        return 'Hari Ini';
      case ReportPeriod.yesterday:
        return 'Kemarin';
      case ReportPeriod.thisWeek:
        return 'Minggu Ini';
      case ReportPeriod.thisMonth:
        return 'Bulan Ini';
      case ReportPeriod.custom:
        if (_customRange != null) {
          final f = DateFormat('dd/MM');
          return '${f.format(_customRange!.start)} - ${f.format(_customRange!.end)}';
        }
        return 'Custom';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Penjualan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _report != null ? _shareReport : null,
            tooltip: 'Share Laporan',
          ),
        ],
      ),
      body: Column(
        children: [
          // Period filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _PeriodChip(
                    label: 'Hari Ini',
                    selected: _period == ReportPeriod.today,
                    onTap: () { setState(() => _period = ReportPeriod.today); _loadReport(); },
                  ),
                  _PeriodChip(
                    label: 'Kemarin',
                    selected: _period == ReportPeriod.yesterday,
                    onTap: () { setState(() => _period = ReportPeriod.yesterday); _loadReport(); },
                  ),
                  _PeriodChip(
                    label: 'Minggu Ini',
                    selected: _period == ReportPeriod.thisWeek,
                    onTap: () { setState(() => _period = ReportPeriod.thisWeek); _loadReport(); },
                  ),
                  _PeriodChip(
                    label: 'Bulan Ini',
                    selected: _period == ReportPeriod.thisMonth,
                    onTap: () { setState(() => _period = ReportPeriod.thisMonth); _loadReport(); },
                  ),
                  _PeriodChip(
                    label: 'Pilih Tanggal',
                    selected: _period == ReportPeriod.custom,
                    onTap: _selectCustomRange,
                    icon: Icons.calendar_month,
                  ),
                ],
              ),
            ),
          ),

          // Report content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _report == null
                    ? const Center(child: Text('Gagal memuat laporan'))
                    : RefreshIndicator(
                        onRefresh: _loadReport,
                        child: _buildReport(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildReport() {
    final summary = _report!['summary'] as Map<String, dynamic>;
    final txCount = summary['transaction_count'] ?? 0;
    final totalSales = (summary['total_sales'] ?? 0).toDouble();
    final totalSubtotal = (summary['total_subtotal'] ?? 0).toDouble();
    final totalPb1 = (summary['total_pb1'] ?? 0).toDouble();
    final totalPpn = (summary['total_ppn'] ?? 0).toDouble();
    final avgTx = (summary['avg_transaction'] ?? 0).toDouble();
    final hasTax = totalPb1 > 0 || totalPpn > 0;

    final paymentBreakdown = _report!['payment_breakdown'] as List<Map<String, dynamic>>;
    final topProducts = _report!['top_products'] as List<Map<String, dynamic>>;
    final hourly = _report!['hourly'] as List<Map<String, dynamic>>;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Period label
        Center(
          child: Text(
            _periodLabel(),
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Summary cards
        _SummaryCard(
          totalSales: totalSales,
          txCount: txCount,
          avgTransaction: avgTx,
          formatCurrency: _formatCurrency,
        ),
        const SizedBox(height: 16),

        // Tax collected
        if (hasTax) ...[
          _SectionTitle(title: 'Pajak Terkumpul'),
          const SizedBox(height: 8),
          _TaxCard(
            subtotal: totalSubtotal,
            pb1: totalPb1,
            ppn: totalPpn,
            total: totalSales,
            formatCurrency: _formatCurrency,
          ),
          const SizedBox(height: 16),
        ],

        // Payment methods
        if (paymentBreakdown.isNotEmpty) ...[
          _SectionTitle(title: 'Metode Pembayaran'),
          const SizedBox(height: 8),
          _PaymentBreakdownCard(
            data: paymentBreakdown,
            totalSales: totalSales,
            formatCurrency: _formatCurrency,
          ),
          const SizedBox(height: 16),
        ],

        // Top products
        if (topProducts.isNotEmpty) ...[
          _SectionTitle(title: 'Produk Terlaris'),
          const SizedBox(height: 8),
          _TopProductsCard(
            products: topProducts,
            formatCurrency: _formatCurrency,
          ),
          const SizedBox(height: 16),
        ],

        // Hourly chart (simple bar)
        if (hourly.isNotEmpty) ...[
          _SectionTitle(title: 'Penjualan per Jam'),
          const SizedBox(height: 8),
          _HourlyChart(data: hourly, formatCurrency: _formatCurrency),
          const SizedBox(height: 16),
        ],

        // Empty state
        if (txCount == 0) ...[
          const SizedBox(height: 48),
          Icon(
            Icons.analytics_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada transaksi di periode ini',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.outline,
              fontSize: 16,
            ),
          ),
        ],
      ],
    );
  }

  String _generateReportText() {
    if (_report == null) return '';

    final summary = _report!['summary'] as Map<String, dynamic>;
    final txCount = summary['transaction_count'] ?? 0;
    final totalSales = (summary['total_sales'] ?? 0).toDouble();
    final totalPb1 = (summary['total_pb1'] ?? 0).toDouble();
    final totalPpn = (summary['total_ppn'] ?? 0).toDouble();
    final paymentBreakdown = _report!['payment_breakdown'] as List<Map<String, dynamic>>;
    final topProducts = _report!['top_products'] as List<Map<String, dynamic>>;

    final buf = StringBuffer();
    buf.writeln('================================');
    buf.writeln('   LAPORAN PENJUALAN');
    buf.writeln('   ${_periodLabel()}');
    buf.writeln('================================');
    buf.writeln('');
    buf.writeln('Total Penjualan: Rp ${_formatCurrency(totalSales)}');
    buf.writeln('Jumlah Transaksi: $txCount');
    if (totalPb1 > 0) buf.writeln('PB1 Terkumpul: Rp ${_formatCurrency(totalPb1)}');
    if (totalPpn > 0) buf.writeln('PPN Terkumpul: Rp ${_formatCurrency(totalPpn)}');
    buf.writeln('');

    if (paymentBreakdown.isNotEmpty) {
      buf.writeln('--- Metode Pembayaran ---');
      for (final pm in paymentBreakdown) {
        buf.writeln('${pm['payment_method']}: ${pm['count']}x = Rp ${_formatCurrency((pm['total'] ?? 0).toDouble())}');
      }
      buf.writeln('');
    }

    if (topProducts.isNotEmpty) {
      buf.writeln('--- Produk Terlaris ---');
      for (var i = 0; i < topProducts.length; i++) {
        final p = topProducts[i];
        buf.writeln('${i + 1}. ${p['product_name']} (${p['total_qty']}x) = Rp ${_formatCurrency((p['total_revenue'] ?? 0).toDouble())}');
      }
    }

    buf.writeln('');
    buf.writeln('================================');
    buf.writeln('  HomeAI POS Voice');
    buf.writeln('================================');

    return buf.toString();
  }

  void _shareReport() {
    Share.share(_generateReportText(), subject: 'Laporan Penjualan - ${_periodLabel()}');
  }
}

// ============ WIDGETS ============

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16),
              const SizedBox(width: 4),
            ],
            Text(label),
          ],
        ),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double totalSales;
  final int txCount;
  final double avgTransaction;
  final String Function(double) formatCurrency;

  const _SummaryCard({
    required this.totalSales,
    required this.txCount,
    required this.avgTransaction,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'Total Penjualan',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Rp ${formatCurrency(totalSales)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MiniStat(
                label: 'Transaksi',
                value: '$txCount',
                icon: Icons.receipt_long,
              ),
              Container(width: 1, height: 30, color: Colors.white24),
              _MiniStat(
                label: 'Rata-rata',
                value: 'Rp ${formatCurrency(avgTransaction)}',
                icon: Icons.trending_up,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
      ],
    );
  }
}

class _TaxCard extends StatelessWidget {
  final double subtotal;
  final double pb1;
  final double ppn;
  final double total;
  final String Function(double) formatCurrency;

  const _TaxCard({
    required this.subtotal,
    required this.pb1,
    required this.ppn,
    required this.total,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _ReportRow(label: 'Subtotal (sebelum pajak)', value: 'Rp ${formatCurrency(subtotal)}'),
            if (pb1 > 0) ...[
              const Divider(),
              _ReportRow(
                label: 'PB1 Terkumpul',
                value: 'Rp ${formatCurrency(pb1)}',
                valueColor: Colors.orange.shade700,
                icon: Icons.account_balance,
              ),
            ],
            if (ppn > 0) ...[
              const Divider(),
              _ReportRow(
                label: 'PPN Terkumpul',
                value: 'Rp ${formatCurrency(ppn)}',
                valueColor: Colors.orange.shade700,
                icon: Icons.account_balance,
              ),
            ],
            const Divider(thickness: 2),
            _ReportRow(
              label: 'Total (inc. pajak)',
              value: 'Rp ${formatCurrency(total)}',
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentBreakdownCard extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final double totalSales;
  final String Function(double) formatCurrency;

  const _PaymentBreakdownCard({
    required this.data,
    required this.totalSales,
    required this.formatCurrency,
  });

  IconData _paymentIcon(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return Icons.payments;
      case 'qris':
        return Icons.qr_code;
      case 'transfer':
        return Icons.account_balance;
      case 'card':
        return Icons.credit_card;
      default:
        return Icons.payment;
    }
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

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var i = 0; i < data.length; i++) ...[
              if (i > 0) const Divider(),
              _PaymentMethodRow(
                icon: _paymentIcon(data[i]['payment_method'] ?? ''),
                label: _paymentLabel(data[i]['payment_method'] ?? '-'),
                count: data[i]['count'] ?? 0,
                total: (data[i]['total'] ?? 0).toDouble(),
                percentage: totalSales > 0 ? ((data[i]['total'] ?? 0).toDouble() / totalSales * 100) : 0,
                formatCurrency: formatCurrency,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final double total;
  final double percentage;
  final String Function(double) formatCurrency;

  const _PaymentMethodRow({
    required this.icon,
    required this.label,
    required this.count,
    required this.total,
    required this.percentage,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  '${count}x transaksi (${percentage.toStringAsFixed(0)}%)',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Text(
            'Rp ${formatCurrency(total)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _TopProductsCard extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final String Function(double) formatCurrency;

  const _TopProductsCard({
    required this.products,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final maxQty = products.isNotEmpty
        ? products.map((p) => (p['total_qty'] ?? 0) as int).reduce((a, b) => a > b ? a : b)
        : 1;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var i = 0; i < products.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _ProductRankRow(
                rank: i + 1,
                name: products[i]['product_name'] ?? '-',
                qty: (products[i]['total_qty'] ?? 0) as int,
                revenue: (products[i]['total_revenue'] ?? 0).toDouble(),
                maxQty: maxQty,
                formatCurrency: formatCurrency,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProductRankRow extends StatelessWidget {
  final int rank;
  final String name;
  final int qty;
  final double revenue;
  final int maxQty;
  final String Function(double) formatCurrency;

  const _ProductRankRow({
    required this.rank,
    required this.name,
    required this.qty,
    required this.revenue,
    required this.maxQty,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final barWidth = maxQty > 0 ? qty / maxQty : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '$rank.',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: rank <= 3 ? Theme.of(context).colorScheme.primary : null,
                ),
              ),
            ),
            Expanded(
              child: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            Text(
              '${qty}x',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              child: Text(
                'Rp ${formatCurrency(revenue)}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: barWidth,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

class _HourlyChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String Function(double) formatCurrency;

  const _HourlyChart({
    required this.data,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxTotal = data.map((d) => (d['total'] ?? 0).toDouble()).reduce((a, b) => a > b ? a : b);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 150,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final d in data)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Tooltip(
                      message: '${d['hour']}:00 — ${d['count']}x, Rp ${formatCurrency((d['total'] ?? 0).toDouble())}',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${d['count']}',
                            style: const TextStyle(fontSize: 9),
                          ),
                          const SizedBox(height: 2),
                          Flexible(
                            child: FractionallySizedBox(
                              heightFactor: maxTotal > 0
                                  ? (d['total'] ?? 0).toDouble() / maxTotal
                                  : 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${d['hour']}',
                            style: TextStyle(
                              fontSize: 9,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;
  final bool isBold;

  const _ReportRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.icon,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: valueColor ?? Theme.of(context).colorScheme.outline),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
