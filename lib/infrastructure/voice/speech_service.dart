import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

/// Speech recognition service using speech_to_text package.
///
/// Handles:
/// - Initialization and permission checks
/// - Start/stop listening
/// - Real-time transcription updates
/// - Error handling
class SpeechService {
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  // Callbacks
  final void Function(String text, bool isFinal)? onResult;
  final void Function(String error)? onError;
  final void Function(String status)? onStatus;

  // Stream controllers for reactive updates
  final _resultController = StreamController<SpeechResult>.broadcast();
  final _statusController = StreamController<SpeechStatus>.broadcast();

  SpeechService({
    this.onResult,
    this.onError,
    this.onStatus,
  });

  /// Stream of speech results.
  Stream<SpeechResult> get resultStream => _resultController.stream;

  /// Stream of status updates.
  Stream<SpeechStatus> get statusStream => _statusController.stream;

  /// Whether speech recognition is available.
  bool get isAvailable => _isInitialized;

  /// Whether currently listening.
  bool get isListening => _isListening;

  /// Initialize the speech service.
  /// Call this once before using the service.
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speech.initialize(
        onStatus: _handleStatus,
        onError: _handleError,
        debugLogging: false,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => false,
      );

      if (_isInitialized) {
        _statusController.add(SpeechStatus.ready);
        onStatus?.call('ready');
      } else {
        _statusController.add(SpeechStatus.unavailable);
        onStatus?.call('unavailable');
      }

      return _isInitialized;
    } catch (e) {
      onError?.call('Gagal inisialisasi: $e');
      _statusController.add(SpeechStatus.error);
      return false;
    }
  }

  /// Start listening for speech.
  Future<bool> startListening({
    String localeId = 'id_ID', // Indonesian
    Duration? listenFor,
    Duration? pauseFor,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    if (_isListening) {
      return true;
    }

    try {
      await _speech.listen(
        onResult: _handleResult,
        localeId: localeId,
        listenFor: listenFor ?? const Duration(seconds: 30),
        pauseFor: pauseFor ?? const Duration(seconds: 3),
        partialResults: true,
        listenMode: ListenMode.confirmation,
      );

      _isListening = true;
      _statusController.add(SpeechStatus.listening);
      onStatus?.call('listening');

      return true;
    } catch (e) {
      onError?.call('Gagal mulai mendengarkan: $e');
      return false;
    }
  }

  /// Stop listening.
  Future<void> stopListening() async {
    if (!_isListening) return;

    await _speech.stop();
    _isListening = false;
    _statusController.add(SpeechStatus.stopped);
    onStatus?.call('stopped');
  }

  /// Cancel listening without processing results.
  Future<void> cancelListening() async {
    if (!_isListening) return;

    await _speech.cancel();
    _isListening = false;
    _statusController.add(SpeechStatus.cancelled);
    onStatus?.call('cancelled');
  }

  /// Get available locales.
  Future<List<LocaleName>> getLocales() async {
    if (!_isInitialized) await initialize();
    return await _speech.locales();
  }

  void _handleResult(SpeechRecognitionResult result) {
    final speechResult = SpeechResult(
      text: result.recognizedWords,
      isFinal: result.finalResult,
      confidence: result.confidence,
    );

    _resultController.add(speechResult);
    onResult?.call(result.recognizedWords, result.finalResult);

    if (result.finalResult) {
      _isListening = false;
      _statusController.add(SpeechStatus.done);
      onStatus?.call('done');
    }
  }

  void _handleStatus(String status) {
    switch (status) {
      case 'listening':
        _statusController.add(SpeechStatus.listening);
        break;
      case 'notListening':
        _isListening = false;
        _statusController.add(SpeechStatus.stopped);
        break;
      case 'done':
        _isListening = false;
        _statusController.add(SpeechStatus.done);
        break;
    }
    onStatus?.call(status);
  }

  void _handleError(SpeechRecognitionError error) {
    _isListening = false;
    _statusController.add(SpeechStatus.error);
    onError?.call(_translateError(error.errorMsg));
  }

  String _translateError(String error) {
    // Translate common errors to Indonesian
    switch (error) {
      case 'error_no_match':
        return 'Tidak dapat mengenali suara';
      case 'error_speech_timeout':
        return 'Waktu habis, coba lagi';
      case 'error_audio':
        return 'Masalah audio, periksa mikrofon';
      case 'error_network':
        return 'Masalah jaringan';
      case 'error_permission':
        return 'Izin mikrofon ditolak';
      default:
        return 'Error: $error';
    }
  }

  /// Dispose resources.
  void dispose() {
    _speech.stop();
    _resultController.close();
    _statusController.close();
  }
}

/// Speech recognition result.
class SpeechResult {
  final String text;
  final bool isFinal;
  final double confidence;

  SpeechResult({
    required this.text,
    required this.isFinal,
    this.confidence = 1.0,
  });
}

/// Speech service status.
enum SpeechStatus {
  ready,
  listening,
  stopped,
  done,
  cancelled,
  error,
  unavailable,
}
