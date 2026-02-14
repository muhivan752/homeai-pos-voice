import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/voice_provider.dart';
import '../providers/product_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/tax_provider.dart';
import '../services/erp_service.dart';
import '../services/sync_service.dart';
import '../services/auth_service.dart';
import '../widgets/cart_list.dart';
import '../widgets/voice_button.dart';
import '../widgets/status_display.dart';
import '../widgets/product_grid.dart';
import '../widgets/sync_indicator.dart';
import '../widgets/barcode_scanner.dart';
import '../widgets/product_search.dart';
import 'history_screen.dart';
import 'menu_management_screen.dart';
import 'payment_screen.dart';
import 'receipt_screen.dart';
import 'report_screen.dart';
import 'login_screen.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _erpService = ErpService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final voice = context.read<VoiceProvider>();
      voice.initialize();
      voice.addListener(_onVoiceChanged);
      _erpService.init();
    });
  }

  @override
  void dispose() {
    // Remove listener safely — provider may already be disposed
    try {
      context.read<VoiceProvider>().removeListener(_onVoiceChanged);
    } catch (_) {}
    super.dispose();
  }

  /// Navigate to receipt screen when voice checkout completes.
  void _onVoiceChanged() {
    final voice = context.read<VoiceProvider>();
    final txId = voice.pendingReceiptTxId;
    if (txId != null) {
      voice.clearPendingReceipt();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiptScreen(
            transactionId: txId,
            isPostCheckout: true,
          ),
        ),
      );
    }
  }

  void _showCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CartBottomSheet(),
    );
  }

  void _showSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ProductSearch(
                  onProductSelected: (product) {
                    final cart = context.read<CartProvider>();
                    cart.addItem(
                      product['id'],
                      product['name'],
                      (product['price'] as num).toDouble(),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${product['name']} ditambahkan'),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openBarcodeScanner(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BarcodeScanner(
          onBarcodeScanned: (barcode) async {
            final productProvider = context.read<ProductProvider>();
            final product = await productProvider.findByBarcode(barcode);

            if (product != null) {
              final cart = context.read<CartProvider>();
              cart.addItem(product.id, product.name, product.price);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${product.name} ditambahkan'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Produk dengan barcode $barcode tidak ditemukan'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.mic, size: 28),
            SizedBox(width: 8),
            Text(
              'POS Voice',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          Consumer<CartProvider>(
            builder: (context, cart, _) => Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined, size: 28),
                  onPressed: _showCart,
                ),
                if (cart.itemCount > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        '${cart.itemCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportScreen()),
              );
            },
            tooltip: 'Laporan',
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
            },
            tooltip: 'Riwayat',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status Display
            const StatusDisplay(),

            // Sync Indicator
            const SyncIndicator(),

            // Search and Scan buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showSearch(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Cari produk...',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: () => _openBarcodeScanner(context),
                      icon: Icon(
                        Icons.qr_code_scanner,
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                      tooltip: 'Scan Barcode',
                    ),
                  ),
                ],
              ),
            ),

            // Category Filter
            Consumer<ProductProvider>(
              builder: (context, productProvider, _) {
                if (productProvider.categories.isEmpty) {
                  return const SizedBox.shrink();
                }
                return CategoryFilter(
                  selectedCategory: productProvider.selectedCategory,
                  categories: productProvider.categories,
                  onCategorySelected: (category) {
                    productProvider.setCategory(category);
                  },
                );
              },
            ),
            const SizedBox(height: 8),

            // Products
            const Expanded(child: ProductGrid()),

            // Bottom Bar with Total
            Consumer2<CartProvider, TaxProvider>(
              builder: (context, cart, tax, _) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _showCart,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${cart.itemCount} item',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Builder(
                              builder: (context) {
                                final breakdown = tax.calculate(cart.total);
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Rp ${_formatCurrency(breakdown.grandTotal)}',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    if (breakdown.hasTax)
                                      Text(
                                        'inc. pajak',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: cart.itemCount > 0 ? () => _checkout(context) : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'BAYAR',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: const VoiceButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void _checkout(BuildContext context) {
    final cart = context.read<CartProvider>();
    final authService = context.read<AuthService>();
    final subtotal = cart.total;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          subtotal: subtotal,
          onPaymentComplete: (result) async {
            Navigator.pop(context);

            // Get customer info if available
            final customerProv = context.read<CustomerProvider>();

            // Process checkout with payment details + tax
            final transactionId = await cart.checkoutWithPayment(
              paymentMethod: result.method,
              paymentAmount: result.amount,
              changeAmount: result.change,
              paymentReference: result.reference,
              cashierId: authService.currentUserId,
              cashierName: authService.currentUserName,
              customerName: customerProv.customerName,
              customerId: customerProv.activeCustomer?.id,
              subtotal: result.subtotal,
              taxPb1: result.taxPb1,
              taxPpn: result.taxPpn,
            );

            // Record customer visit
            if (transactionId != null && customerProv.hasCustomer) {
              await customerProv.recordVisit(transactionId);
            }

            if (transactionId != null) {
              // Navigate to receipt screen
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReceiptScreen(
                      transactionId: transactionId,
                      isPostCheckout: true,
                    ),
                  ),
                );
              }
            } else if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Gagal menyimpan transaksi. Coba lagi.'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SettingsSheet(erpService: _erpService),
    );
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}

class CartBottomSheet extends StatelessWidget {
  const CartBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.shopping_cart),
                  const SizedBox(width: 8),
                  const Text(
                    'Keranjang',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      context.read<CartProvider>().clearCart();
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Hapus'),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Cart Items
            Expanded(
              child: CartList(scrollController: scrollController),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsSheet extends StatelessWidget {
  final ErpService erpService;

  const SettingsSheet({super.key, required this.erpService});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // User Info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authService.currentUserName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    authService.isAdmin ? 'Administrator' : 'Kasir',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.restaurant_menu,
            iconColor: Colors.deepPurple,
            title: 'Kelola Menu',
            subtitle: 'Tambah, edit, hapus produk',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MenuManagementScreen()),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.receipt_long,
            iconColor: Colors.teal,
            title: 'Pajak (PB1 & PPN)',
            subtitle: _taxSubtitle(context),
            onTap: () {
              Navigator.pop(context);
              _showTaxSettings(context);
            },
          ),
          _SettingsTile(
            icon: Icons.cloud_outlined,
            iconColor: Colors.blue,
            title: 'ERPNext Server',
            subtitle: erpService.isConfigured
                ? erpService.baseUrl ?? 'Terkonfigurasi'
                : 'Belum dikonfigurasi',
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (context) => ErpSettingsDialog(erpService: erpService),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.history,
            iconColor: Colors.green,
            title: 'Riwayat Transaksi',
            subtitle: 'Lihat semua transaksi',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.analytics,
            iconColor: Colors.deepPurple,
            title: 'Laporan Penjualan',
            subtitle: 'Harian, mingguan, bulanan + pajak',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportScreen()),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.sync,
            iconColor: Colors.orange,
            title: 'Sinkronisasi Produk',
            subtitle: 'Ambil produk dari ERPNext',
            onTap: () {
              Navigator.pop(context);
              _syncProducts(context);
            },
          ),
          _SettingsTile(
            icon: Icons.info_outline,
            iconColor: Colors.grey,
            title: 'Tentang Aplikasi',
            subtitle: 'HomeAI POS Voice v1.0.0',
            onTap: () {},
          ),
          const Divider(),
          _SettingsTile(
            icon: Icons.logout,
            iconColor: Colors.red,
            title: 'Keluar',
            subtitle: 'Logout dari aplikasi',
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Konfirmasi Logout'),
                  content: const Text('Apakah Anda yakin ingin keluar?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('BATAL'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        authService.logout();
                        Navigator.pop(ctx);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('KELUAR'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _syncProducts(BuildContext context) async {
    if (!erpService.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konfigurasi ERPNext terlebih dahulu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mengambil produk dari ERPNext...')),
    );

    final result = await erpService.getProducts();

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Berhasil mengambil ${result.data!.length} produk'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Gagal mengambil produk'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _taxSubtitle(BuildContext context) {
    final tax = context.watch<TaxProvider>();
    if (!tax.pb1Enabled && !tax.ppnEnabled) return 'Nonaktif';
    final parts = <String>[];
    if (tax.pb1Enabled) parts.add('PB1 ${tax.pb1Rate.toStringAsFixed(0)}%');
    if (tax.ppnEnabled) parts.add('PPN ${tax.ppnRate.toStringAsFixed(0)}%');
    return parts.join(' + ');
  }

  void _showTaxSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _TaxSettingsDialog(),
    );
  }
}

class _TaxSettingsDialog extends StatelessWidget {
  const _TaxSettingsDialog();

  @override
  Widget build(BuildContext context) {
    return Consumer<TaxProvider>(
      builder: (context, tax, _) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.teal),
              SizedBox(width: 8),
              Text('Pengaturan Pajak'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // PB1 toggle
                _TaxToggleRow(
                  label: 'PB1 (Pajak Restoran)',
                  sublabel: 'Pajak daerah untuk restoran/kafe',
                  enabled: tax.pb1Enabled,
                  rate: tax.pb1Rate,
                  onToggle: (v) => tax.setPb1Enabled(v),
                  onRateChanged: (v) => tax.setPb1Rate(v),
                ),
                const Divider(height: 24),
                // PPN toggle
                _TaxToggleRow(
                  label: 'PPN (Pajak Pertambahan Nilai)',
                  sublabel: 'Pajak nasional',
                  enabled: tax.ppnEnabled,
                  rate: tax.ppnRate,
                  onToggle: (v) => tax.setPpnEnabled(v),
                  onRateChanged: (v) => tax.setPpnRate(v),
                ),
                const SizedBox(height: 16),
                // Preview
                if (tax.hasTaxEnabled) _TaxPreview(tax: tax),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('TUTUP'),
            ),
          ],
        );
      },
    );
  }
}

class _TaxToggleRow extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool enabled;
  final double rate;
  final ValueChanged<bool> onToggle;
  final ValueChanged<double> onRateChanged;

  const _TaxToggleRow({
    required this.label,
    required this.sublabel,
    required this.enabled,
    required this.rate,
    required this.onToggle,
    required this.onRateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Text(sublabel, style: const TextStyle(fontSize: 12)),
          value: enabled,
          onChanged: onToggle,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        if (enabled)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Row(
              children: [
                const Text('Tarif: ', style: TextStyle(fontSize: 13)),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: TextEditingController(text: rate.toStringAsFixed(0)),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      suffixText: '%',
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 14),
                    onSubmitted: (v) {
                      final parsed = double.tryParse(v);
                      if (parsed != null && parsed >= 0 && parsed <= 100) {
                        onRateChanged(parsed);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TaxPreview extends StatelessWidget {
  final TaxProvider tax;

  const _TaxPreview({required this.tax});

  @override
  Widget build(BuildContext context) {
    // Example calculation with 100k subtotal
    final example = tax.calculate(100000);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contoh (Subtotal Rp 100.000):',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          if (example.pb1Amount > 0)
            _previewLine(context, 'PB1', example.pb1Amount),
          if (example.ppnAmount > 0)
            _previewLine(context, 'PPN', example.ppnAmount),
          const Divider(height: 8),
          _previewLine(context, 'Total', example.grandTotal, bold: true),
        ],
      ),
    );
  }

  Widget _previewLine(BuildContext context, String label, double amount, {bool bold = false}) {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text('Rp $formatted', style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class ErpSettingsDialog extends StatefulWidget {
  final ErpService erpService;

  const ErpSettingsDialog({super.key, required this.erpService});

  @override
  State<ErpSettingsDialog> createState() => _ErpSettingsDialogState();
}

class _ErpSettingsDialogState extends State<ErpSettingsDialog> {
  final _urlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _apiSecretController = TextEditingController();
  bool _isLoading = false;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _urlController.text = widget.erpService.baseUrl ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.cloud, color: Colors.blue),
          SizedBox(width: 8),
          Text('ERPNext Server'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Server URL',
                hintText: 'https://erp.example.com',
                prefixIcon: const Icon(Icons.link),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                labelText: 'API Key',
                prefixIcon: const Icon(Icons.key),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiSecretController,
              decoration: InputDecoration(
                labelText: 'API Secret',
                prefixIcon: const Icon(Icons.lock),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isTesting ? null : _testConnection,
                icon: _isTesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_find),
                label: Text(_isTesting ? 'Mengecek...' : 'Test Koneksi'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('BATAL'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveSettings,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('SIMPAN'),
        ),
      ],
    );
  }

  Future<void> _testConnection() async {
    setState(() => _isTesting = true);

    // Save temporarily for testing
    await widget.erpService.saveConfig(
      url: _urlController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      apiSecret: _apiSecretController.text.trim(),
    );

    final result = await widget.erpService.testConnection();

    setState(() => _isTesting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isSuccess ? 'Koneksi berhasil!' : result.errorMessage!,
          ),
          backgroundColor: result.isSuccess ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);

    await widget.erpService.saveConfig(
      url: _urlController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      apiSecret: _apiSecretController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengaturan disimpan'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _apiKeyController.dispose();
    _apiSecretController.dispose();
    super.dispose();
  }
}
