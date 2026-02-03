import 'package:flutter/material.dart';
import '../../domain/domain.dart';
import '../theme/pos_theme.dart';
import 'product_card.dart';

/// Product catalog with grid layout and category tabs.
class ProductCatalog extends StatefulWidget {
  final List<Product> products;
  final Function(Product product) onProductTap;
  final bool showCategoryTabs;
  final bool compactMode;

  const ProductCatalog({
    super.key,
    required this.products,
    required this.onProductTap,
    this.showCategoryTabs = true,
    this.compactMode = false,
  });

  @override
  State<ProductCatalog> createState() => _ProductCatalogState();
}

class _ProductCatalogState extends State<ProductCatalog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _updateCategories();
  }

  @override
  void didUpdateWidget(ProductCatalog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.products != widget.products) {
      _updateCategories();
    }
  }

  void _updateCategories() {
    // Extract unique categories
    final categories = <String>{'Semua'};
    for (final product in widget.products) {
      if (product.category != null && product.category!.isNotEmpty) {
        categories.add(product.category!);
      }
    }
    _categories = categories.toList();

    // Reinitialize tab controller
    _tabController = TabController(
      length: _categories.length,
      vsync: this,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Product> get _filteredProducts {
    if (_tabController.index == 0) {
      return widget.products;
    }
    final selectedCategory = _categories[_tabController.index];
    return widget.products
        .where((p) => p.category == selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.products.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // Category tabs
        if (widget.showCategoryTabs && _categories.length > 1)
          _buildCategoryTabs(),

        // Product grid
        Expanded(
          child: widget.compactMode
              ? _buildCompactList()
              : _buildProductGrid(),
        ),
      ],
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      margin: const EdgeInsets.only(bottom: PosTheme.paddingSmall),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: PosTheme.primary,
        unselectedLabelColor: PosTheme.textSecondary,
        indicatorColor: PosTheme.primary,
        indicatorWeight: 3,
        labelStyle: PosTheme.labelLarge,
        unselectedLabelStyle: PosTheme.bodyMedium,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        tabs: _categories.map((cat) => Tab(text: cat)).toList(),
      ),
    );
  }

  Widget _buildProductGrid() {
    final products = _filteredProducts;

    return GridView.builder(
      padding: const EdgeInsets.all(PosTheme.paddingSmall),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: PosTheme.paddingSmall,
        mainAxisSpacing: PosTheme.paddingSmall,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return ProductCard(
          product: product,
          onTap: product.isAvailable
              ? () => widget.onProductTap(product)
              : null,
        );
      },
    );
  }

  Widget _buildCompactList() {
    final products = _filteredProducts;

    return ListView.separated(
      padding: const EdgeInsets.all(PosTheme.paddingSmall),
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: PosTheme.paddingSmall),
      itemBuilder: (context, index) {
        final product = products[index];
        return ProductCard(
          product: product,
          compact: true,
          onTap: product.isAvailable
              ? () => widget.onProductTap(product)
              : null,
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: PosTheme.textMuted.withOpacity(0.5),
          ),
          const SizedBox(height: PosTheme.paddingMedium),
          Text(
            'Tidak ada produk',
            style: PosTheme.titleLarge.copyWith(color: PosTheme.textMuted),
          ),
          const SizedBox(height: PosTheme.paddingSmall),
          Text(
            'Katalog produk belum tersedia',
            style: PosTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// Simple horizontal product list for quick access.
class ProductQuickList extends StatelessWidget {
  final List<Product> products;
  final Function(Product product) onProductTap;
  final String? title;

  const ProductQuickList({
    super.key,
    required this.products,
    required this.onProductTap,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PosTheme.paddingMedium,
              vertical: PosTheme.paddingSmall,
            ),
            child: Text(title!, style: PosTheme.titleMedium),
          ),
        ],
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: PosTheme.paddingMedium),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: PosTheme.paddingSmall),
            itemBuilder: (context, index) {
              final product = products[index];
              return _QuickProductChip(
                product: product,
                onTap: product.isAvailable
                    ? () => onProductTap(product)
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _QuickProductChip extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;

  const _QuickProductChip({
    required this.product,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = product.isAvailable;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
        child: Container(
          width: 100,
          padding: const EdgeInsets.all(PosTheme.paddingSmall),
          decoration: BoxDecoration(
            color: isAvailable ? PosTheme.surface : PosTheme.background,
            borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
            border: Border.all(color: PosTheme.divider),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.coffee,
                color: isAvailable ? PosTheme.primary : PosTheme.textMuted,
                size: 28,
              ),
              const SizedBox(height: 4),
              Text(
                product.name,
                style: PosTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isAvailable ? PosTheme.textPrimary : PosTheme.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              Text(
                formatRupiah(product.price),
                style: PosTheme.bodyMedium.copyWith(
                  fontSize: 11,
                  color: isAvailable ? PosTheme.primary : PosTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
