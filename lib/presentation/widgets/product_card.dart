import 'package:flutter/material.dart';
import '../../domain/domain.dart';
import '../theme/pos_theme.dart';

/// Product card for displaying menu items.
/// Tappable to add to cart.
class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  final bool compact;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = product.isAvailable;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isAvailable ? onTap : null,
        borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
        child: Container(
          decoration: BoxDecoration(
            color: isAvailable ? PosTheme.surface : PosTheme.background,
            borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
            border: Border.all(
              color: isAvailable ? PosTheme.divider : PosTheme.divider,
              width: 1,
            ),
            boxShadow: isAvailable
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: compact ? _buildCompactLayout() : _buildStandardLayout(),
        ),
      ),
    );
  }

  Widget _buildStandardLayout() {
    final isAvailable = product.isAvailable;

    return Padding(
      padding: const EdgeInsets.all(PosTheme.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Product icon/image placeholder
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              color: isAvailable
                  ? PosTheme.primary.withOpacity(0.1)
                  : PosTheme.textMuted.withOpacity(0.1),
              borderRadius: BorderRadius.circular(PosTheme.radiusSmall),
            ),
            child: Icon(
              _getProductIcon(),
              size: 32,
              color: isAvailable ? PosTheme.primary : PosTheme.textMuted,
            ),
          ),
          const SizedBox(height: PosTheme.paddingSmall),

          // Product name
          Text(
            product.name,
            style: PosTheme.titleMedium.copyWith(
              color: isAvailable ? PosTheme.textPrimary : PosTheme.textMuted,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          // Price
          Text(
            formatRupiah(product.price),
            style: PosTheme.priceTag.copyWith(
              fontSize: 18,
              color: isAvailable ? PosTheme.primary : PosTheme.textMuted,
            ),
          ),

          const SizedBox(height: 4),

          // Stock indicator
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isAvailable ? PosTheme.success : PosTheme.error,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                isAvailable ? 'Stok: ${product.stock}' : 'Habis',
                style: PosTheme.bodyMedium.copyWith(
                  fontSize: 12,
                  color: isAvailable ? PosTheme.textSecondary : PosTheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactLayout() {
    final isAvailable = product.isAvailable;

    return Padding(
      padding: const EdgeInsets.all(PosTheme.paddingSmall),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isAvailable
                  ? PosTheme.primary.withOpacity(0.1)
                  : PosTheme.textMuted.withOpacity(0.1),
              borderRadius: BorderRadius.circular(PosTheme.radiusSmall),
            ),
            child: Icon(
              _getProductIcon(),
              size: 24,
              color: isAvailable ? PosTheme.primary : PosTheme.textMuted,
            ),
          ),
          const SizedBox(width: PosTheme.paddingSmall),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.name,
                  style: PosTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isAvailable ? PosTheme.textPrimary : PosTheme.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  formatRupiah(product.price),
                  style: PosTheme.bodyMedium.copyWith(
                    color: isAvailable ? PosTheme.primary : PosTheme.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Stock indicator
          if (!isAvailable)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: PosTheme.errorLight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Habis',
                style: PosTheme.bodyMedium.copyWith(
                  color: PosTheme.error,
                  fontSize: 12,
                ),
              ),
            )
          else
            Icon(
              Icons.add_circle,
              color: PosTheme.primary,
              size: 28,
            ),
        ],
      ),
    );
  }

  IconData _getProductIcon() {
    final category = product.category?.toLowerCase() ?? '';
    if (category.contains('kopi')) {
      return Icons.coffee;
    } else if (category.contains('teh')) {
      return Icons.local_cafe;
    }
    return Icons.restaurant;
  }
}
