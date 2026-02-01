import 'package:flutter/material.dart';
import '../../domain/entities/cart_item.dart';
import '../theme/pos_theme.dart';

/// Single cart item display.
class CartItemTile extends StatelessWidget {
  final CartItem item;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final bool showActions;

  const CartItemTile({
    super.key,
    required this.item,
    this.onTap,
    this.onRemove,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
      child: Container(
        padding: const EdgeInsets.all(PosTheme.paddingMedium),
        decoration: BoxDecoration(
          color: PosTheme.cardBackground,
          borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
          border: Border.all(color: PosTheme.divider),
        ),
        child: Row(
          children: [
            // Quantity badge
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: PosTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(PosTheme.radiusSmall),
              ),
              child: Center(
                child: Text(
                  '${item.qty}x',
                  style: PosTheme.labelLarge.copyWith(
                    color: PosTheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: PosTheme.paddingMedium),

            // Item details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.item,
                    style: PosTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatRupiah(item.rate)} / item',
                    style: PosTheme.bodyMedium,
                  ),
                ],
              ),
            ),

            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatRupiah(item.amount),
                  style: PosTheme.priceTag,
                ),
                if (showActions && onRemove != null)
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                    color: PosTheme.error,
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
