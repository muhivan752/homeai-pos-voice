import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/voice_provider.dart';
import '../providers/cart_provider.dart';

class VoiceButton extends StatelessWidget {
  const VoiceButton({super.key});

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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '"${voice.lastWords}"',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),

            // Voice FAB
            FloatingActionButton.large(
              onPressed: isProcessing
                  ? null
                  : () async {
                      if (isListening) {
                        await voice.stopListening();
                        voice.processCommand(context.read<CartProvider>());
                      } else {
                        await voice.startListening();
                      }
                    },
              backgroundColor: isListening
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
              child: isProcessing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Icon(
                      isListening ? Icons.stop : Icons.mic,
                      size: 36,
                      color: Colors.white,
                    ),
            ),
          ],
        );
      },
    );
  }
}
