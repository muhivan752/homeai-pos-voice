import 'package:flutter/material.dart';
import '../theme/pos_theme.dart';

/// Displays voice recognition feedback to user.
///
/// Shows:
/// - Recognized speech text (live)
/// - Success/error message after processing
/// - Visual indicator of state
class VoiceFeedback extends StatelessWidget {
  final String? recognizedText;
  final String? message;
  final bool isListening;
  final bool isSuccess;
  final bool isError;

  const VoiceFeedback({
    super.key,
    this.recognizedText,
    this.message,
    this.isListening = false,
    this.isSuccess = false,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    // Don't show if nothing to display
    if (!isListening &&
        recognizedText == null &&
        message == null) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(PosTheme.paddingMedium),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
        border: Border.all(color: _borderColor, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status indicator row
          Row(
            children: [
              _buildStatusIcon(),
              const SizedBox(width: PosTheme.paddingSmall),
              Text(
                _statusText,
                style: PosTheme.labelLarge.copyWith(
                  color: _textColor,
                ),
              ),
            ],
          ),

          // Recognized text (if listening or just finished)
          if (recognizedText != null && recognizedText!.isNotEmpty) ...[
            const SizedBox(height: PosTheme.paddingSmall),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(PosTheme.paddingSmall),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(PosTheme.radiusSmall),
              ),
              child: Text(
                '"$recognizedText"',
                style: PosTheme.bodyLarge.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],

          // Result message
          if (message != null && message!.isNotEmpty) ...[
            const SizedBox(height: PosTheme.paddingSmall),
            Text(
              message!,
              style: PosTheme.bodyLarge.copyWith(
                color: _textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusIcon() {
    if (isListening) {
      return const _PulsingDot(color: PosTheme.error);
    }
    if (isSuccess) {
      return const Icon(
        Icons.check_circle,
        color: PosTheme.success,
        size: 24,
      );
    }
    if (isError) {
      return const Icon(
        Icons.error,
        color: PosTheme.error,
        size: 24,
      );
    }
    return const Icon(
      Icons.info_outline,
      color: PosTheme.textSecondary,
      size: 24,
    );
  }

  String get _statusText {
    if (isListening) return 'Mendengarkan...';
    if (isSuccess) return 'Berhasil';
    if (isError) return 'Gagal';
    return 'Info';
  }

  Color get _backgroundColor {
    if (isListening) return PosTheme.warningLight;
    if (isSuccess) return PosTheme.successLight;
    if (isError) return PosTheme.errorLight;
    return PosTheme.background;
  }

  Color get _borderColor {
    if (isListening) return PosTheme.warning;
    if (isSuccess) return PosTheme.success;
    if (isError) return PosTheme.error;
    return PosTheme.divider;
  }

  Color get _textColor {
    if (isListening) return PosTheme.warning;
    if (isSuccess) return PosTheme.success;
    if (isError) return PosTheme.error;
    return PosTheme.textPrimary;
  }
}

/// Pulsing dot indicator for listening state.
class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({required this.color});

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
      duration: const Duration(milliseconds: 800),
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
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.3 + (_controller.value * 0.7)),
          ),
          child: Center(
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
              ),
            ),
          ),
        );
      },
    );
  }
}
