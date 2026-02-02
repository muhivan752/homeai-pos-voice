import 'package:flutter/material.dart';
import '../theme/pos_theme.dart';

/// Text input for voice command fallback.
///
/// Features:
/// - Large touch-friendly input
/// - Submit on enter
/// - Clear button
/// - Hint text with examples
class CommandInput extends StatefulWidget {
  final ValueChanged<String> onSubmit;
  final bool enabled;
  final String? hintText;

  const CommandInput({
    super.key,
    required this.onSubmit,
    this.enabled = true,
    this.hintText,
  });

  @override
  State<CommandInput> createState() => _CommandInputState();
}

class _CommandInputState extends State<CommandInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSubmit(text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
        border: Border.all(color: PosTheme.divider),
      ),
      child: Row(
        children: [
          // Icon
          const Padding(
            padding: EdgeInsets.only(left: PosTheme.paddingMedium),
            child: Icon(
              Icons.keyboard,
              color: PosTheme.textMuted,
            ),
          ),

          // Text field
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: widget.hintText ?? 'Ketik perintah...',
                hintStyle: PosTheme.bodyLarge.copyWith(
                  color: PosTheme.textMuted,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: PosTheme.paddingMedium,
                  vertical: PosTheme.paddingMedium,
                ),
              ),
              style: PosTheme.bodyLarge,
            ),
          ),

          // Clear button (when there's text)
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, child) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                onPressed: () => _controller.clear(),
                icon: const Icon(Icons.clear),
                color: PosTheme.textMuted,
              );
            },
          ),

          // Submit button
          Container(
            margin: const EdgeInsets.all(4),
            child: IconButton(
              onPressed: widget.enabled ? _submit : null,
              icon: const Icon(Icons.send),
              color: PosTheme.primary,
              style: IconButton.styleFrom(
                backgroundColor: PosTheme.primary.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(PosTheme.radiusSmall),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick action chips for common commands.
class QuickActions extends StatelessWidget {
  final ValueChanged<String> onAction;
  final bool isCustomer;

  const QuickActions({
    super.key,
    required this.onAction,
    this.isCustomer = false,
  });

  @override
  Widget build(BuildContext context) {
    final actions = isCustomer ? _customerActions : _staffActions;

    return Wrap(
      spacing: PosTheme.paddingSmall,
      runSpacing: PosTheme.paddingSmall,
      children: actions.map((action) {
        return ActionChip(
          label: Text(action.label),
          avatar: Icon(action.icon, size: 18),
          onPressed: () => onAction(action.command),
          backgroundColor: PosTheme.surface,
          side: const BorderSide(color: PosTheme.divider),
          labelStyle: PosTheme.bodyMedium,
        );
      }).toList(),
    );
  }

  static const _staffActions = [
    _QuickAction('Total', Icons.calculate, 'totalnya berapa'),
    _QuickAction('Keranjang', Icons.shopping_cart, 'isi keranjang'),
    _QuickAction('Bayar', Icons.payment, 'bayar'),
    _QuickAction('Batal Tadi', Icons.undo, 'batal yang tadi'),
    _QuickAction('Kosongkan', Icons.delete_sweep, 'kosongkan keranjang'),
    _QuickAction('Bantuan', Icons.help, 'bantuan'),
  ];

  static const _customerActions = [
    _QuickAction('Lihat Total', Icons.calculate, 'totalnya berapa'),
    _QuickAction('Lihat Keranjang', Icons.shopping_cart, 'isi keranjang'),
    _QuickAction('Bantuan', Icons.help, 'bantuan'),
  ];
}

class _QuickAction {
  final String label;
  final IconData icon;
  final String command;

  const _QuickAction(this.label, this.icon, this.command);
}
