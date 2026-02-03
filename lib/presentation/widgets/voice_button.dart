import 'package:flutter/material.dart';
import '../theme/pos_theme.dart';

/// Voice input button with visual feedback.
///
/// States:
/// - idle: Ready to listen
/// - listening: Actively capturing speech
/// - processing: Intent being processed
/// - success: Command executed
/// - error: Command failed
enum VoiceButtonState {
  idle,
  listening,
  processing,
  success,
  error,
}

class VoiceButton extends StatefulWidget {
  final VoiceButtonState state;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;
  final double size;
  final bool enabled;

  const VoiceButton({
    super.key,
    this.state = VoiceButtonState.idle,
    this.onPressed,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.size = 80,
    this.enabled = true,
  });

  @override
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(VoiceButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == VoiceButtonState.listening) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.enabled ? widget.onPressed : null,
      onLongPressStart:
          widget.enabled ? (_) => widget.onLongPressStart?.call() : null,
      onLongPressEnd:
          widget.enabled ? (_) => widget.onLongPressEnd?.call() : null,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final scale = widget.state == VoiceButtonState.listening
              ? _pulseAnimation.value
              : 1.0;
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _backgroundColor,
            boxShadow: [
              BoxShadow(
                color: _backgroundColor.withOpacity(0.4),
                blurRadius: widget.state == VoiceButtonState.listening ? 20 : 10,
                spreadRadius:
                    widget.state == VoiceButtonState.listening ? 2 : 0,
              ),
            ],
          ),
          child: Icon(
            _icon,
            color: Colors.white,
            size: widget.size * 0.5,
          ),
        ),
      ),
    );
  }

  Color get _backgroundColor {
    if (!widget.enabled) {
      return PosTheme.textMuted;
    }
    switch (widget.state) {
      case VoiceButtonState.idle:
        return PosTheme.primary;
      case VoiceButtonState.listening:
        return PosTheme.error;
      case VoiceButtonState.processing:
        return PosTheme.warning;
      case VoiceButtonState.success:
        return PosTheme.success;
      case VoiceButtonState.error:
        return PosTheme.error;
    }
  }

  IconData get _icon {
    switch (widget.state) {
      case VoiceButtonState.idle:
        return Icons.mic;
      case VoiceButtonState.listening:
        return Icons.mic;
      case VoiceButtonState.processing:
        return Icons.hourglass_top;
      case VoiceButtonState.success:
        return Icons.check;
      case VoiceButtonState.error:
        return Icons.error_outline;
    }
  }
}
