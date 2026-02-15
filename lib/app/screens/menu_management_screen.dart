import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';

class MenuManagementScreen extends StatelessWidget {
  const MenuManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Menu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showProductForm(context),
            tooltip: 'Tambah Produk',
          ),
        ],
      ),
      body: Consumer<ProductProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final products = provider.allProducts;

          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.restaurant_menu,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada produk',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showProductForm(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah Produk Pertama'),
                  ),
                ],
              ),
            );
          }

          // Group by category
          final grouped = <String, List<Product>>{};
          for (final p in products) {
            grouped.putIfAbsent(p.category, () => []).add(p);
          }

          final categoryOrder = ['drink', 'food', 'snack', 'other'];
          final sortedKeys = grouped.keys.toList()
            ..sort((a, b) {
              final ia = categoryOrder.indexOf(a);
              final ib = categoryOrder.indexOf(b);
              return (ia == -1 ? 99 : ia).compareTo(ib == -1 ? 99 : ib);
            });

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: sortedKeys.length,
            itemBuilder: (context, index) {
              final category = sortedKeys[index];
              final items = grouped[category]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Icon(
                          _categoryIcon(category),
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _categoryLabel(category),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${items.length})',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Product items
                  ...items.map((product) => _ProductTile(
                    product: product,
                    onEdit: () => _showProductForm(context, product: product),
                    onDelete: () => _confirmDelete(context, product),
                  )),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
    );
  }

  void _showProductForm(BuildContext context, {Product? product}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProductFormSheet(
        product: product,
        onSave: (newProduct) async {
          final provider = context.read<ProductProvider>();
          if (product != null) {
            await provider.updateProduct(newProduct);
          } else {
            await provider.addProduct(newProduct);
          }
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Produk'),
        content: Text('Yakin mau hapus "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<ProductProvider>().deleteProduct(product.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${product.name} dihapus'),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('HAPUS'),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'drink': return Icons.local_cafe;
      case 'food': return Icons.restaurant;
      case 'snack': return Icons.cookie;
      default: return Icons.category;
    }
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'drink': return 'Minuman';
      case 'food': return 'Makanan';
      case 'snack': return 'Snack';
      default: return 'Lainnya';
    }
  }
}

// --- Product Tile ---

class _ProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductTile({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: Key(product.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // Let dialog handle the delete
      },
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _getIcon(product.category),
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                product.aliases.isNotEmpty
                    ? product.aliases.take(3).join(', ')
                    : 'Tanpa alias',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (product.isStockTracked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: product.isOutOfStock
                      ? Colors.red.withOpacity(0.1)
                      : product.isLowStock
                          ? Colors.orange.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  product.isOutOfStock
                      ? 'Habis'
                      : 'Stok: ${product.stock}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: product.isOutOfStock
                        ? Colors.red
                        : product.isLowStock
                            ? Colors.orange.shade700
                            : Colors.green.shade700,
                  ),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Rp ${_formatCurrency(product.price)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 20, color: colorScheme.primary),
              onPressed: onEdit,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }

  IconData _getIcon(String category) {
    switch (category) {
      case 'drink': return Icons.local_cafe;
      case 'food': return Icons.restaurant;
      case 'snack': return Icons.cookie;
      default: return Icons.inventory_2;
    }
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}

// --- Product Form Bottom Sheet ---

class _ProductFormSheet extends StatefulWidget {
  final Product? product;
  final Future<void> Function(Product product) onSave;

  const _ProductFormSheet({this.product, required this.onSave});

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _aliasController;
  late TextEditingController _barcodeController;
  late TextEditingController _stockController;
  String _selectedCategory = 'drink';
  bool _trackStock = false;
  bool _isSaving = false;

  bool get isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _priceController = TextEditingController(
      text: p != null ? p.price.toStringAsFixed(0) : '',
    );
    _aliasController = TextEditingController(
      text: p?.aliases.join(', ') ?? '',
    );
    _barcodeController = TextEditingController(text: p?.barcode ?? '');
    _trackStock = p != null && p.isStockTracked;
    _stockController = TextEditingController(
      text: _trackStock ? p!.stock.toString() : '',
    );
    _selectedCategory = p?.category ?? 'drink';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _aliasController.dispose();
    _barcodeController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
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
                  Icon(
                    isEditing ? Icons.edit : Icons.add_circle_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEditing ? 'Edit Produk' : 'Tambah Produk Baru',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Form
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Nama Produk *',
                          hintText: 'Contoh: Kopi Susu',
                          prefixIcon: const Icon(Icons.fastfood),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Nama produk wajib diisi';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Price
                      TextFormField(
                        controller: _priceController,
                        decoration: InputDecoration(
                          labelText: 'Harga (Rp) *',
                          hintText: 'Contoh: 18000',
                          prefixIcon: const Icon(Icons.payments),
                          prefixText: 'Rp ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Harga wajib diisi';
                          final price = double.tryParse(v.replaceAll('.', '').replaceAll(',', ''));
                          if (price == null || price <= 0) return 'Harga harus lebih dari 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Category
                      const Text(
                        'Kategori',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _CategoryChip(
                            label: 'Minuman',
                            icon: Icons.local_cafe,
                            selected: _selectedCategory == 'drink',
                            onTap: () => setState(() => _selectedCategory = 'drink'),
                          ),
                          _CategoryChip(
                            label: 'Makanan',
                            icon: Icons.restaurant,
                            selected: _selectedCategory == 'food',
                            onTap: () => setState(() => _selectedCategory = 'food'),
                          ),
                          _CategoryChip(
                            label: 'Snack',
                            icon: Icons.cookie,
                            selected: _selectedCategory == 'snack',
                            onTap: () => setState(() => _selectedCategory = 'snack'),
                          ),
                          _CategoryChip(
                            label: 'Lainnya',
                            icon: Icons.category,
                            selected: _selectedCategory == 'other',
                            onTap: () => setState(() => _selectedCategory = 'other'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Aliases
                      TextFormField(
                        controller: _aliasController,
                        decoration: InputDecoration(
                          labelText: 'Alias (untuk voice)',
                          hintText: 'kopi susu, kosu, coffee milk',
                          helperText: 'Pisahkan dengan koma. Bantu voice mengenali produk ini.',
                          prefixIcon: const Icon(Icons.mic),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),

                      // Stock tracking
                      Row(
                        children: [
                          const Icon(Icons.inventory, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Lacak Stok',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          Switch(
                            value: _trackStock,
                            onChanged: (v) => setState(() => _trackStock = v),
                          ),
                        ],
                      ),
                      if (_trackStock) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _stockController,
                          decoration: InputDecoration(
                            labelText: 'Jumlah Stok',
                            hintText: 'Contoh: 50',
                            prefixIcon: const Icon(Icons.inventory_2),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (!_trackStock) return null;
                            if (v == null || v.trim().isEmpty) return 'Jumlah stok wajib diisi';
                            final stock = int.tryParse(v.trim());
                            if (stock == null || stock < 0) return 'Stok harus 0 atau lebih';
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Barcode
                      TextFormField(
                        controller: _barcodeController,
                        decoration: InputDecoration(
                          labelText: 'Barcode (opsional)',
                          hintText: 'Scan atau ketik barcode',
                          prefixIcon: const Icon(Icons.qr_code),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 24),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(isEditing ? Icons.save : Icons.add),
                          label: Text(
                            isEditing ? 'SIMPAN PERUBAHAN' : 'TAMBAH PRODUK',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
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
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final price = double.parse(
        _priceController.text.replaceAll('.', '').replaceAll(',', '').trim(),
      );
      final aliases = _aliasController.text
          .split(',')
          .map((a) => a.trim().toLowerCase())
          .where((a) => a.isNotEmpty)
          .toList();
      final barcode = _barcodeController.text.trim().isEmpty
          ? null
          : _barcodeController.text.trim();

      // Generate ID from name (slug)
      final id = isEditing
          ? widget.product!.id
          : name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

      // Auto-add name as first alias if not already present
      final lowerName = name.toLowerCase();
      if (!aliases.contains(lowerName)) {
        aliases.insert(0, lowerName);
      }

      final stock = _trackStock
          ? int.parse(_stockController.text.trim())
          : -1;

      final product = Product(
        id: id,
        name: name,
        price: price,
        category: _selectedCategory,
        aliases: aliases,
        barcode: barcode,
        stock: stock,
      );

      await widget.onSave(product);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? '$name diperbarui' : '$name ditambahkan'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

// --- Category Chip for form ---

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: selected ? Colors.white : colorScheme.primary),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: colorScheme.primary,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : colorScheme.onSurface,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
