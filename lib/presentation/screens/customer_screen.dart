import 'package:flutter/material.dart';
import '../../application/pos_voice_service.dart';
import '../../domain/domain.dart';
import '../theme/pos_theme.dart';
import '../widgets/widgets.dart';

/// Customer mode screen - read-only cart view.
///
/// Principle: Customer = speed
/// - Clear, large display of cart items
/// - Total prominently shown
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
    _loadCart();
  }

  Future<void> _loadCart() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get cart from service
      final cartResult = await widget.service.handleVoice('isi keranjang');
      final totalResult = await widget.service.handleVoice('totalnya berapa');

      // Parse the results (in real app, service would return structured data)
      // For now, we'll call the ERP adapter directly through the service
      await _refreshCartData();
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal memuat keranjang';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshCartData() async {
    // Using voice commands to get cart data
    final cartResult = await widget.service.handleVoice('isi keranjang');
    final totalResult = await widget.service.handleVoice('total');

    setState(() {
      // The service returns VoiceResult with message
      // In real implementation, we'd have direct access to cart data
      _feedbackMessage = cartResult.message;
    });
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
      await _refreshCartData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PosTheme.customerAccent.withValues(alpha: 0.05),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Main content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildContent(),
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
        ),
      ),
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
            onPressed: _loadCart,
            icon: const Icon(Icons.refresh),
            color: PosTheme.textSecondary,
          ),
        ],
      ),
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
              onPressed: _loadCart,
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
            color: PosTheme.textMuted.withValues(alpha: 0.5),
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
        color: PosTheme.customerAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
        border: Border.all(color: PosTheme.customerAccent.withValues(alpha: 0.3)),
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
