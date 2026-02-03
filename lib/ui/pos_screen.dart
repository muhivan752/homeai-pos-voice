import '../application/pos_voice_service.dart';

/// POS Screen - UI layer.
///
/// ATURAN ARSITEKTUR:
/// - HANYA import PosVoiceService dari application layer
/// - TIDAK BOLEH import IntentParser, IntentExecutor, ERP adapter
/// - Semua dependency di-inject dari entrypoint
///
/// Contoh penggunaan (Flutter StatefulWidget):
/// ```dart
/// class PosScreenState extends State<PosScreen> {
///   late final PosVoiceService service;
///
///   @override
///   void initState() {
///     super.initState();
///     // service di-inject dari widget parent atau provider
///     service = widget.service;
///   }
///
///   void onMicPressed(String spokenText) async {
///     final result = await service.handleVoice(spokenText);
///     if (result.isSuccess) {
///       showSuccess(result.message);
///     } else {
///       showError(result.message);
///     }
///   }
/// }
/// ```

class PosScreen {
  final PosVoiceService service;

  PosScreen({required this.service});

  Future<void> onVoiceInput(String spokenText) async {
    final result = await service.handleVoice(spokenText);

    if (result.isSuccess) {
      _showSuccess(result.message);
    } else {
      _showError(result.message);
    }
  }

  void _showSuccess(String message) {
    print('[UI] $message');
  }

  void _showError(String message) {
    print('[UI] ERROR: $message');
  }
}
