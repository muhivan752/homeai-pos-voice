import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/voice_provider.dart';
import '../providers/cart_provider.dart';

class VoiceButton extends StatelessWidget {
  const VoiceButton({super.key});

  void _showTextInput(BuildContext context) {
    final controller = TextEditingController();
    final voice = context.read<VoiceProvider>();
    final cart = context.read<CartProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
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
              Text(
                'Ketik perintah',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(ctx).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Misal: "kopi susu 2", "bayar qris", "batal latte"',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: 'Tulis pesanan di sini...',
                        filled: true,
                        fillColor: Theme.of(ctx)
                            .colorScheme
                            .surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      onSubmitted: (text) {
                        if (text.trim().isNotEmpty) {
                          voice.processText(text.trim(), cart);
                          Navigator.pop(ctx);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IconButton(
                      onPressed: () {
                        final text = controller.text.trim();
                        if (text.isNotEmpty) {
                          voice.processText(text, cart);
                          Navigator.pop(ctx);
                        }
                      },
                      icon: const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Quick action chips
              Wrap(
                spacing: 8,
                children: [
                  _QuickChip(
                    label: 'Kopi Susu',
                    onTap: () {
                      voice.processText('kopi susu', cart);
                      Navigator.pop(ctx);
                    },
                  ),
                  _QuickChip(
                    label: 'Latte',
                    onTap: () {
                      voice.processText('latte', cart);
                      Navigator.pop(ctx);
                    },
                  ),
                  _QuickChip(
                    label: 'Americano',
                    onTap: () {
                      voice.processText('americano', cart);
                      Navigator.pop(ctx);
                    },
                  ),
                  _QuickChip(
                    label: 'Bayar',
                    onTap: () {
                      voice.processText('bayar', cart);
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceProvider>(
      builder: (context, voice, _) {
        final isListening = voice.isListening;
        final isProcessing = voice.status == VoiceStatus.processing;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Recognized text display
            if (voice.lastWords.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '"${voice.lastWords}"',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),

            // Mic + Keyboard buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Keyboard button (text input fallback)
                FloatingActionButton(
                  heroTag: 'keyboard_fab',
                  onPressed: isProcessing
                      ? null
                      : () => _showTextInput(context),
                  backgroundColor:
                      Theme.of(context).colorScheme.secondaryContainer,
                  child: Icon(
                    Icons.keyboard,
                    color:
                        Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 16),

                // Voice FAB (main)
                FloatingActionButton.large(
                  heroTag: 'voice_fab',
                  onPressed: isProcessing
                      ? null
                      : () async {
                          if (isListening) {
                            // CRITICAL: capture text BEFORE stopping
                            // speech.stop() can trigger a final empty callback
                            // that clears _lastWords
                            final capturedText = voice.lastWords;
                            await voice.stopListening();
                            if (capturedText.isNotEmpty) {
                              voice.processText(
                                capturedText,
                                context.read<CartProvider>(),
                              );
                            }
                          } else {
                            await voice.startListening();
                          }
                        },
                  backgroundColor: isListening
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                  child: isProcessing
                      ? const CircularProgressIndicator(
                          color: Colors.white)
                      : Icon(
                          isListening ? Icons.stop : Icons.mic,
                          size: 36,
                          color: Colors.white,
                        ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.onPrimaryContainer,
        fontSize: 13,
      ),
    );
  }
}
