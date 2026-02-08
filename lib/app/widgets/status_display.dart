import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/voice_provider.dart';
import '../providers/cart_provider.dart';

class StatusDisplay extends StatelessWidget {
  const StatusDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<VoiceProvider, CartProvider>(
      builder: (context, voice, cart, _) {
        final isListening = voice.status == VoiceStatus.listening;
        final hasCartMessage = cart.lastMessage.isNotEmpty;

        Color bgColor;
        Color textColor;
        IconData icon;
        String message;

        if (isListening) {
          bgColor = Theme.of(context).colorScheme.error.withOpacity(0.1);
          textColor = Theme.of(context).colorScheme.error;
          icon = Icons.mic;
          message = voice.statusMessage;
        } else if (hasCartMessage) {
          bgColor = cart.isSuccess
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Theme.of(context).colorScheme.error.withOpacity(0.1);
          textColor = cart.isSuccess
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.error;
          icon = cart.isSuccess ? Icons.check_circle : Icons.error;
          message = cart.lastMessage;
        } else {
          bgColor = Theme.of(context).colorScheme.surfaceContainerHighest;
          textColor = Theme.of(context).colorScheme.onSurface;
          icon = Icons.info_outline;
          message = voice.statusMessage;
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: textColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isListening)
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: textColor,
                    shape: BoxShape.circle,
                  ),
                  child: const _PulsingDot(),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.3 + (_controller.value * 0.7),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
