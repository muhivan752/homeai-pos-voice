import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/tax_provider.dart';

class PaymentScreen extends StatefulWidget {
  final double subtotal;
  final Function(PaymentResult) onPaymentComplete;

  const PaymentScreen({
    super.key,
    required this.subtotal,
    required this.onPaymentComplete,
  });

  /// Backwards-compat: accept `total` as alias for `subtotal`.
  factory PaymentScreen.legacy({
    Key? key,
    required double total,
    required Function(PaymentResult) onPaymentComplete,
  }) {
    return PaymentScreen(
      key: key,
      subtotal: total,
      onPaymentComplete: onPaymentComplete,
    );
  }

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedMethod = 'cash';
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  double _change = 0;

  final List<Map<String, dynamic>> _paymentMethods = [
    {'id': 'cash', 'name': 'Tunai', 'icon': Icons.payments_outlined, 'color': Colors.green},
    {'id': 'qris', 'name': 'QRIS', 'icon': Icons.qr_code_2, 'color': Colors.purple},
    {'id': 'transfer', 'name': 'Transfer', 'icon': Icons.account_balance, 'color': Colors.blue},
    {'id': 'card', 'name': 'Kartu', 'icon': Icons.credit_card, 'color': Colors.orange},
  ];

  final List<int> _quickAmounts = [10000, 20000, 50000, 100000, 200000, 500000];

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_calculateChange);
  }

  void _calculateChange() {
    final tax = context.read<TaxProvider>().calculate(widget.subtotal);
    final amount = double.tryParse(_amountController.text.replaceAll('.', '')) ?? 0;
    setState(() {
      _change = amount - tax.grandTotal;
      if (_change < 0) _change = 0;
    });
  }

  void _setAmount(double amount) {
    _amountController.text = amount.toStringAsFixed(0);
    _calculateChange();
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  void _processPayment() {
    final tax = context.read<TaxProvider>().calculate(widget.subtotal);
    double paymentAmount = tax.grandTotal;

    if (_selectedMethod == 'cash') {
      paymentAmount = double.tryParse(_amountController.text.replaceAll('.', '')) ?? tax.grandTotal;
      if (paymentAmount < tax.grandTotal) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jumlah uang kurang!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    widget.onPaymentComplete(PaymentResult(
      method: _selectedMethod,
      amount: paymentAmount,
      change: _selectedMethod == 'cash' ? _change : 0,
      reference: _referenceController.text.trim(),
      subtotal: widget.subtotal,
      taxPb1: tax.pb1Amount,
      taxPpn: tax.ppnAmount,
      grandTotal: tax.grandTotal,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TaxProvider>(
      builder: (context, taxProvider, _) {
        final tax = taxProvider.calculate(widget.subtotal);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Pembayaran'),
            centerTitle: true,
          ),
          body: Column(
            children: [
              // Total Amount + Tax Breakdown
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Column(
                  children: [
                    // Tax breakdown (if any tax enabled)
                    if (tax.hasTax) ...[
                      _TaxLine(
                        label: 'Subtotal',
                        amount: tax.subtotal,
                        formatCurrency: _formatCurrency,
                      ),
                      if (tax.pb1Amount > 0)
                        _TaxLine(
                          label: 'PB1 (${taxProvider.pb1Rate.toStringAsFixed(0)}%)',
                          amount: tax.pb1Amount,
                          formatCurrency: _formatCurrency,
                        ),
                      if (tax.ppnAmount > 0)
                        _TaxLine(
                          label: 'PPN (${taxProvider.ppnRate.toStringAsFixed(0)}%)',
                          amount: tax.ppnAmount,
                          formatCurrency: _formatCurrency,
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Divider(
                          color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.3),
                        ),
                      ),
                    ],
                    Text(
                      tax.hasTax ? 'Total Pembayaran' : 'Total Pembayaran',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rp ${_formatCurrency(tax.grandTotal)}',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Payment Methods
                      const Text(
                        'Metode Pembayaran',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 4,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1,
                        children: _paymentMethods.map((method) {
                          final isSelected = _selectedMethod == method['id'];
                          return GestureDetector(
                            onTap: () {
                              setState(() => _selectedMethod = method['id']);
                              if (method['id'] != 'cash') {
                                _amountController.text = tax.grandTotal.toStringAsFixed(0);
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (method['color'] as Color).withOpacity(0.15)
                                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? method['color'] as Color
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    method['icon'] as IconData,
                                    color: method['color'] as Color,
                                    size: 28,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    method['name'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Cash-specific input
                      if (_selectedMethod == 'cash') ...[
                        const Text(
                          'Jumlah Uang',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _amountController,
                          decoration: InputDecoration(
                            prefixText: 'Rp ',
                            hintText: '0',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Quick amounts
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _quickAmounts.map((amount) {
                            return ActionChip(
                              label: Text(
                                'Rp ${_formatCurrency(amount.toDouble())}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              onPressed: () => _setAmount(amount.toDouble()),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        ActionChip(
                          label: const Text('Uang Pas'),
                          avatar: const Icon(Icons.check, size: 16),
                          onPressed: () => _setAmount(tax.grandTotal),
                        ),
                        const SizedBox(height: 24),

                        // Change display
                        if (_change > 0)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.payments, color: Colors.green.shade700),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Kembalian',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Rp ${_formatCurrency(_change)}',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],

                      // Reference input for non-cash
                      if (_selectedMethod != 'cash') ...[
                        const Text(
                          'Referensi (Opsional)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _referenceController,
                          decoration: InputDecoration(
                            hintText: _selectedMethod == 'qris'
                                ? 'ID Transaksi QRIS'
                                : _selectedMethod == 'transfer'
                                    ? 'No. Referensi Transfer'
                                    : 'No. Approval',
                            prefixIcon: const Icon(Icons.tag),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Info for non-cash
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedMethod == 'qris'
                                      ? 'Pastikan pembayaran QRIS sudah berhasil sebelum melanjutkan'
                                      : _selectedMethod == 'transfer'
                                          ? 'Pastikan transfer sudah diterima sebelum melanjutkan'
                                          : 'Pastikan transaksi kartu sudah berhasil',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom button
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
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _processPayment,
                      icon: const Icon(Icons.check_circle),
                      label: Text(
                        _selectedMethod == 'cash' && _change > 0
                            ? 'BAYAR (Kembalian: Rp ${_formatCurrency(_change)})'
                            : 'KONFIRMASI PEMBAYARAN',
                        style: const TextStyle(
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
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }
}

/// Tax line item in the payment header.
class _TaxLine extends StatelessWidget {
  final String label;
  final double amount;
  final String Function(double) formatCurrency;

  const _TaxLine({
    required this.label,
    required this.amount,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
            ),
          ),
          Text(
            'Rp ${formatCurrency(amount)}',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentResult {
  final String method;
  final double amount;
  final double change;
  final String reference;
  final double subtotal;
  final double taxPb1;
  final double taxPpn;
  final double grandTotal;

  PaymentResult({
    required this.method,
    required this.amount,
    required this.change,
    required this.reference,
    this.subtotal = 0,
    this.taxPb1 = 0,
    this.taxPpn = 0,
    this.grandTotal = 0,
  });
}
