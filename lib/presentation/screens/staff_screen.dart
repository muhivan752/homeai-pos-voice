import 'package:flutter/material.dart';
import '../../application/pos_voice_service.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/cart_total.dart';
import '../../infrastructure/auth/auth_context.dart';
import '../theme/pos_theme.dart';
import '../widgets/widgets.dart';

/// Staff mode screen - full POS with voice/text input.
///
/// Principle: Staff = safety
/// - Full cart operations
/// - Voice + text input
/// - Clear confirmations
/// - Role-based feature visibility
class StaffScreen extends StatefulWidget {
  final PosVoiceService service;
  final AuthContext auth;
  final VoidCallback onLogout;

  const StaffScreen({
    super.key,
    required this.service,
    required this.auth,
    required this.onLogout,
  });

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  List<CartItem> _cartItems = [];
  CartTotal? _cartTotal;
  bool _isLoading = false;

  // Voice state
  VoiceButtonState _voiceState = VoiceButtonState.idle;
  String? _recognizedText;
  String? _feedbackMessage;
  bool _isSuccess = false;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    // Silent refresh - don't show loading for quick refreshes
    await _refreshCartData();
  }

  Future<void> _refreshCartData() async {
    // Get cart data through service
    // In real implementation, service would expose cart state directly
    final result = await widget.service.handleVoice('isi keranjang');
    if (result.isSuccess) {
      // Parse cart from message (demo - real app would have structured data)
    }
  }

  Future<void> _handleCommand(String command) async {
    setState(() {
      _recognizedText = command;
      _voiceState = VoiceButtonState.processing;
      _isSuccess = false;
      _isError = false;
      _feedbackMessage = null;
    });

    final result = await widget.service.handleVoice(command);

    setState(() {
      _feedbackMessage = result.message;
      _isSuccess = result.isSuccess;
      _isError = !result.isSuccess;
      _voiceState = result.isSuccess
          ? VoiceButtonState.success
          : VoiceButtonState.error;
    });

    // Reset to idle after delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _voiceState = VoiceButtonState.idle;
        });
      }
    });

    // Clear feedback after longer delay
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _recognizedText = null;
          _feedbackMessage = null;
          _isSuccess = false;
          _isError = false;
        });
      }
    });

    // Refresh cart data
    await _refreshCartData();
  }

  void _startListening() {
    setState(() {
      _voiceState = VoiceButtonState.listening;
      _recognizedText = null;
      _feedbackMessage = null;
    });
    // Voice integration will be added later
  }

  void _stopListening() {
    setState(() {
      _voiceState = VoiceButtonState.idle;
    });
    // Voice integration will be added later
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // Left panel - Cart
            Expanded(
              flex: 3,
              child: _buildCartPanel(),
            ),

            // Divider
            const VerticalDivider(width: 1),

            // Right panel - Input & Actions
            Expanded(
              flex: 2,
              child: _buildInputPanel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartPanel() {
    return Column(
      children: [
        // Header
        _buildCartHeader(),

        // Cart items
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildCartList(),
        ),

        // Total section
        _buildTotalSection(),
      ],
    );
  }

  Widget _buildCartHeader() {
    return Container(
      padding: const EdgeInsets.all(PosTheme.paddingMedium),
      decoration: const BoxDecoration(
        color: PosTheme.surface,
        border: Border(bottom: BorderSide(color: PosTheme.divider)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shopping_cart, color: PosTheme.primary),
          const SizedBox(width: PosTheme.paddingSmall),
          Text('Keranjang', style: PosTheme.headlineMedium),
          const Spacer(),
          Text(
            '${_cartItems.length} item',
            style: PosTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildCartList() {
    if (_cartItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: PosTheme.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: PosTheme.paddingMedium),
            Text(
              'Keranjang kosong',
              style: PosTheme.titleLarge.copyWith(color: PosTheme.textMuted),
            ),
            const SizedBox(height: PosTheme.paddingSmall),
            Text(
              'Ucapkan "jual kopi" untuk menambah',
              style: PosTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(PosTheme.paddingMedium),
      itemCount: _cartItems.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: PosTheme.paddingSmall),
      itemBuilder: (context, index) {
        final item = _cartItems[index];
        return CartItemTile(
          item: item,
          showActions: true,
          onRemove: () => _handleCommand('hapus ${item.item}'),
          onTap: () => _showItemOptions(item),
        );
      },
    );
  }

  void _showItemOptions(CartItem item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(PosTheme.radiusLarge),
        ),
      ),
      builder: (context) => _ItemOptionsSheet(
        item: item,
        onChangeQty: (qty) {
          Navigator.pop(context);
          _handleCommand('${item.item} jadi $qty');
        },
        onRemove: () {
          Navigator.pop(context);
          _handleCommand('hapus ${item.item}');
        },
      ),
    );
  }

  Widget _buildTotalSection() {
    return Container(
      padding: const EdgeInsets.all(PosTheme.paddingMedium),
      decoration: const BoxDecoration(
        color: PosTheme.surface,
        border: Border(top: BorderSide(color: PosTheme.divider)),
      ),
      child: Column(
        children: [
          // Subtotal row
          if (_cartTotal != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Subtotal', style: PosTheme.bodyLarge),
                Text(
                  formatRupiah(_cartTotal!.total),
                  style: PosTheme.bodyLarge,
                ),
              ],
            ),
            if (_cartTotal!.discount > 0) ...[
              const SizedBox(height: PosTheme.paddingSmall),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Diskon',
                    style: PosTheme.bodyMedium.copyWith(color: PosTheme.success),
                  ),
                  Text(
                    '- ${formatRupiah(_cartTotal!.discount)}',
                    style:
                        PosTheme.bodyMedium.copyWith(color: PosTheme.success),
                  ),
                ],
              ),
            ],
            const Divider(),
          ],

          // Grand total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: PosTheme.headlineMedium),
              Text(
                formatRupiah(_cartTotal?.grandTotal ?? 0),
                style: PosTheme.totalPrice,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputPanel() {
    return Container(
      color: PosTheme.background,
      child: Column(
        children: [
          // Header with user info
          _buildUserHeader(),

          // Voice feedback area
          Expanded(
            child: _buildVoiceArea(),
          ),

          // Quick actions
          _buildQuickActions(),

          // Input area
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildUserHeader() {
    return Container(
      padding: const EdgeInsets.all(PosTheme.paddingMedium),
      decoration: const BoxDecoration(
        color: PosTheme.surface,
        border: Border(bottom: BorderSide(color: PosTheme.divider)),
      ),
      child: Row(
        children: [
          // User avatar
          CircleAvatar(
            backgroundColor: PosTheme.primary.withValues(alpha: 0.1),
            child: Text(
              widget.auth.userName?.substring(0, 1).toUpperCase() ??
                  widget.auth.role.displayName.substring(0, 1),
              style: PosTheme.titleLarge.copyWith(color: PosTheme.primary),
            ),
          ),
          const SizedBox(width: PosTheme.paddingSmall),

          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.auth.userName ?? widget.auth.role.displayName,
                  style: PosTheme.titleMedium,
                ),
                Text(
                  widget.auth.role.displayName,
                  style: PosTheme.bodyMedium,
                ),
              ],
            ),
          ),

          // Logout button
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
            color: PosTheme.textSecondary,
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceArea() {
    return Padding(
      padding: const EdgeInsets.all(PosTheme.paddingMedium),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Voice button
          VoiceButton(
            state: _voiceState,
            onPressed: () {
              if (_voiceState == VoiceButtonState.idle) {
                _startListening();
              } else if (_voiceState == VoiceButtonState.listening) {
                _stopListening();
              }
            },
            onLongPressStart: _startListening,
            onLongPressEnd: _stopListening,
            size: 100,
          ),
          const SizedBox(height: PosTheme.paddingMedium),

          // Instruction text
          Text(
            _voiceState == VoiceButtonState.listening
                ? 'Bicara sekarang...'
                : 'Tekan untuk bicara',
            style: PosTheme.bodyLarge.copyWith(
              color: PosTheme.textSecondary,
            ),
          ),
          const SizedBox(height: PosTheme.paddingLarge),

          // Voice feedback
          if (_recognizedText != null || _feedbackMessage != null)
            VoiceFeedback(
              recognizedText: _recognizedText,
              message: _feedbackMessage,
              isListening: _voiceState == VoiceButtonState.listening,
              isSuccess: _isSuccess,
              isError: _isError,
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PosTheme.paddingMedium),
      child: QuickActions(
        onAction: _handleCommand,
        isCustomer: false,
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(PosTheme.paddingMedium),
      decoration: const BoxDecoration(
        color: PosTheme.surface,
        border: Border(top: BorderSide(color: PosTheme.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Text input
          CommandInput(
            onSubmit: _handleCommand,
            hintText: 'Ketik perintah, misal: "jual kopi 2"',
          ),
          const SizedBox(height: PosTheme.paddingMedium),

          // Checkout button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _cartItems.isNotEmpty
                  ? () => _handleCommand('bayar')
                  : null,
              icon: const Icon(Icons.payment),
              label: const Padding(
                padding: EdgeInsets.all(PosTheme.paddingSmall),
                child: Text('Bayar'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: PosTheme.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet for item options.
class _ItemOptionsSheet extends StatelessWidget {
  final CartItem item;
  final ValueChanged<int> onChangeQty;
  final VoidCallback onRemove;

  const _ItemOptionsSheet({
    required this.item,
    required this.onChangeQty,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(PosTheme.paddingLarge),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: PosTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: PosTheme.paddingMedium),

          // Item name
          Text(
            item.item,
            style: PosTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: PosTheme.paddingLarge),

          // Quantity selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filled(
                onPressed: item.qty > 1 ? () => onChangeQty(item.qty - 1) : null,
                icon: const Icon(Icons.remove),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: PosTheme.paddingLarge),
                child: Text(
                  '${item.qty}',
                  style: PosTheme.displayMedium,
                ),
              ),
              IconButton.filled(
                onPressed: () => onChangeQty(item.qty + 1),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: PosTheme.paddingLarge),

          // Remove button
          OutlinedButton.icon(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Hapus dari keranjang'),
            style: OutlinedButton.styleFrom(
              foregroundColor: PosTheme.error,
              side: const BorderSide(color: PosTheme.error),
            ),
          ),
          const SizedBox(height: PosTheme.paddingMedium),
        ],
      ),
    );
  }
}
