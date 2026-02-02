import 'package:flutter/material.dart';
import '../../application/pos_voice_service.dart';
import '../../domain/domain.dart';
import '../theme/pos_theme.dart';
import '../widgets/widgets.dart';

/// Customer mode screen - read-only cart view with product catalog.
///
/// Principle: Customer = speed
/// - Clear, large display of cart items
/// - Total prominently shown
/// - Product catalog visible for reference
/// - Auto-refresh when cart changes
/// - Voice command limited to inquiry only
class CustomerScreen extends StatefulWidget {
  final PosVoiceService service;
  final VoidCallback onExit;

  const CustomerScreen({
    super.key,
    required this.service,
    required this.onExit,
  });

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  List<CartItem> _cartItems = [];
  List<Product> _products = [];
  CartTotal? _cartTotal;
  bool _isLoading = true;
  String? _errorMessage;

  // Voice state
  String? _recognizedText;
  String? _feedbackMessage;
  bool _isListening = false;
  bool _isSuccess = false;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Future.wait([
        _loadProducts(),
        _loadCart(),
      ]);
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal memuat data';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProducts() async {
    try {
      final products = await widget.service.getCatalog();
      if (mounted) {
        setState(() => _products = products);
      }
    } catch (e) {
      print('[CustomerScreen] Error loading products: $e');
    }
  }

  Future<void> _loadCart() async {
    try {
      final cartItems = await widget.service.getCartItems();
      final cartTotal = await widget.service.getCartTotal();
      if (mounted) {
        setState(() {
          _cartItems = cartItems;
          _cartTotal = cartTotal;
        });
      }
    } catch (e) {
      print('[CustomerScreen] Error loading cart: $e');
    }
  }

  Future<void> _handleVoiceCommand(String command) async {
    setState(() {
      _recognizedText = command;
      _isListening = false;
      _isSuccess = false;
      _isError = false;
    });

    final result = await widget.service.handleVoice(command);

    setState(() {
      _feedbackMessage = result.message;
      _isSuccess = result.isSuccess;
      _isError = !result.isSuccess;
    });

    // Clear feedback after delay
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _recognizedText = null;
          _feedbackMessage = null;
          _isSuccess = false;
          _isError = false;
        });
      }
    });

    // Refresh cart if inquiry command
    if (result.isSuccess) {
      await _loadCart();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 900;

    return Scaffold(
      backgroundColor: PosTheme.customerAccent.withOpacity(0.03),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : isWideScreen
                ? _buildWideLayout()
                : _buildCompactLayout(),
      ),
    );
  }

  /// Wide layout: 2 columns (Products | Cart)
  Widget _buildWideLayout() {
    return Column(
      children: [
        // Header
        _buildHeader(),

        // Content
        Expanded(
          child: Row(
            children: [
              // Left - Product catalog (reference)
              Expanded(
                flex: 3,
                child: _buildProductPanel(),
              ),
              const VerticalDivider(width: 1),

              // Right - Cart and total
              Expanded(
                flex: 2,
                child: _buildCartPanel(),
              ),
            ],
          ),
        ),

        // Voice feedback
        if (_recognizedText != null || _feedbackMessage != null)
          Padding(
            padding: const EdgeInsets.all(PosTheme.paddingMedium),
            child: VoiceFeedback(
              recognizedText: _recognizedText,
              message: _feedbackMessage,
              isListening: _isListening,
              isSuccess: _isSuccess,
              isError: _isError,
            ),
          ),

        // Bottom actions
        _buildBottomActions(),
      ],
    );
  }

  /// Compact layout: Single column
  Widget _buildCompactLayout() {
    return Column(
      children: [
        // Header
        _buildHeader(),

        // Product quick list
        _buildProductQuickList(),
        const Divider(height: 1),

        // Main content
        Expanded(child: _buildContent()),

        // Voice feedback
        if (_recognizedText != null || _feedbackMessage != null)
          Padding(
            padding: const EdgeInsets.all(PosTheme.paddingMedium),
            child: VoiceFeedback(
              recognizedText: _recognizedText,
              message: _feedbackMessage,
              isListening: _isListening,
              isSuccess: _isSuccess,
              isError: _isError,
            ),
          ),

        // Bottom actions
        _buildBottomActions(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(PosTheme.paddingMedium),
      decoration: const BoxDecoration(
        color: PosTheme.surface,
        border: Border(
          bottom: BorderSide(color: PosTheme.divider),
        ),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: widget.onExit,
            icon: const Icon(Icons.arrow_back),
            color: PosTheme.textSecondary,
          ),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Pesanan Anda',
                  style: PosTheme.headlineMedium.copyWith(
                    color: PosTheme.customerAccent,
                  ),
                ),
                Text(
                  'Mode Pelanggan',
                  style: PosTheme.bodyMedium,
                ),
              ],
            ),
          ),

          // Refresh button
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            color: PosTheme.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildProductPanel() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(PosTheme.paddingMedium),
          decoration: const BoxDecoration(
            color: PosTheme.surface,
            border: Border(bottom: BorderSide(color: PosTheme.divider)),
          ),
          child: Row(
            children: [
              Icon(Icons.restaurant_menu, color: PosTheme.customerAccent),
              const SizedBox(width: PosTheme.paddingSmall),
              Text(
                'Menu Tersedia',
                style: PosTheme.headlineMedium.copyWith(
                  color: PosTheme.customerAccent,
                ),
              ),
              const Spacer(),
              Text(
                '${_products.length} produk',
                style: PosTheme.bodyMedium,
              ),
            ],
          ),
        ),

        // Product catalog (read-only, no onTap action)
        Expanded(
          child: ProductCatalog(
            products: _products,
            onProductTap: (_) {}, // No action for customer
          ),
        ),
      ],
    );
  }

  Widget _buildProductQuickList() {
    return Container(
      color: PosTheme.surface,
      child: ProductQuickList(
        products: _products,
        onProductTap: (_) {}, // No action for customer
        title: 'Menu Tersedia',
      ),
    );
  }

  Widget _buildCartPanel() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(PosTheme.paddingMedium),
          decoration: const BoxDecoration(
            color: PosTheme.surface,
            border: Border(bottom: BorderSide(color: PosTheme.divider)),
          ),
          child: Row(
            children: [
              Icon(Icons.shopping_cart, color: PosTheme.customerAccent),
              const SizedBox(width: PosTheme.paddingSmall),
              Text(
                'Keranjang',
                style: PosTheme.headlineMedium.copyWith(
                  color: PosTheme.customerAccent,
                ),
              ),
              const Spacer(),
              Text(
                '${_cartItems.length} item',
                style: PosTheme.bodyMedium,
              ),
            ],
          ),
        ),

        // Cart items
        Expanded(
          child: _cartItems.isEmpty
              ? _buildEmptyCart()
              : ListView.separated(
                  padding: const EdgeInsets.all(PosTheme.paddingMedium),
                  itemCount: _cartItems.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: PosTheme.paddingSmall),
                  itemBuilder: (context, index) {
                    return CartItemTile(
                      item: _cartItems[index],
                      showActions: false, // Read-only for customer
                    );
                  },
                ),
        ),

        // Total display
        if (_cartTotal != null) _buildTotalCard(),
      ],
    );
  }

  Widget _buildContent() {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: PosTheme.error,
            ),
            const SizedBox(height: PosTheme.paddingMedium),
            Text(
              _errorMessage!,
              style: PosTheme.bodyLarge,
            ),
            const SizedBox(height: PosTheme.paddingMedium),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(PosTheme.paddingMedium),
      child: Column(
        children: [
          // Cart items (scrollable)
          Expanded(
            child: _cartItems.isEmpty
                ? _buildEmptyCart()
                : ListView.separated(
                    itemCount: _cartItems.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: PosTheme.paddingSmall),
                    itemBuilder: (context, index) {
                      return CartItemTile(
                        item: _cartItems[index],
                        showActions: false, // Read-only for customer
                      );
                    },
                  ),
          ),

          // Total display
          if (_cartTotal != null) ...[
            const Divider(),
            _buildTotalCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: PosTheme.textMuted.withOpacity(0.5),
          ),
          const SizedBox(height: PosTheme.paddingMedium),
          Text(
            'Keranjang kosong',
            style: PosTheme.headlineMedium.copyWith(
              color: PosTheme.textMuted,
            ),
          ),
          const SizedBox(height: PosTheme.paddingSmall),
          Text(
            'Silakan tunggu staff menambahkan pesanan',
            style: PosTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard() {
    return Container(
      padding: const EdgeInsets.all(PosTheme.paddingLarge),
      decoration: BoxDecoration(
        color: PosTheme.customerAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
        border: Border.all(color: PosTheme.customerAccent.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total',
                style: PosTheme.titleLarge,
              ),
              Text(
                '${_cartTotal!.itemCount} item',
                style: PosTheme.bodyMedium,
              ),
            ],
          ),
          Text(
            formatRupiah(_cartTotal!.grandTotal),
            style: PosTheme.displayMedium.copyWith(
              color: PosTheme.customerAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(PosTheme.paddingMedium),
      decoration: const BoxDecoration(
        color: PosTheme.surface,
        border: Border(
          top: BorderSide(color: PosTheme.divider),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick actions for customer
          QuickActions(
            onAction: _handleVoiceCommand,
            isCustomer: true,
          ),
          const SizedBox(height: PosTheme.paddingMedium),

          // Text input for commands
          CommandInput(
            onSubmit: _handleVoiceCommand,
            hintText: 'Tanya "total" atau "isi keranjang"...',
          ),
        ],
      ),
    );
  }
}
