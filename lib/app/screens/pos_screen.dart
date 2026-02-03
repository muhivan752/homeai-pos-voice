import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/voice_provider.dart';
import '../widgets/cart_list.dart';
import '../widgets/voice_button.dart';
import '../widgets/status_display.dart';
import '../widgets/product_grid.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VoiceProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HomeAI POS Voice'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              context.read<CartProvider>().clearCart();
            },
            tooltip: 'Kosongkan Keranjang',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status Display
            const StatusDisplay(),

            // Main Content
            Expanded(
              child: Row(
                children: [
                  // Product Grid (Left)
                  const Expanded(
                    flex: 3,
                    child: ProductGrid(),
                  ),

                  // Divider
                  const VerticalDivider(width: 1),

                  // Cart (Right)
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        // Cart Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Row(
                            children: [
                              const Icon(Icons.shopping_cart),
                              const SizedBox(width: 8),
                              const Text(
                                'Keranjang',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Consumer<CartProvider>(
                                builder: (context, cart, _) => Text(
                                  '${cart.itemCount} item',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Cart Items
                        const Expanded(child: CartList()),

                        // Total & Checkout
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Consumer<CartProvider>(
                                builder: (context, cart, _) => Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total:',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Rp ${_formatCurrency(cart.total)}',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    context.read<CartProvider>().checkout();
                                  },
                                  icon: const Icon(Icons.payment),
                                  label: const Text('CHECKOUT'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: const VoiceButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}
