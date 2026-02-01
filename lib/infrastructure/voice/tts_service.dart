import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-speech service for voice feedback.
///
/// Handles:
/// - Speaking text in Indonesian
/// - Queue management
/// - Volume/rate control
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;

  // Callbacks
  final void Function()? onStart;
  final void Function()? onComplete;
  final void Function(String error)? onError;

  // Settings
  double _volume = 1.0;
  double _rate = 0.5; // Slower for clarity
  double _pitch = 1.0;
  String _language = 'id-ID';

  TtsService({
    this.onStart,
    this.onComplete,
    this.onError,
  });

  /// Whether TTS is available.
  bool get isAvailable => _isInitialized;

  /// Whether currently speaking.
  bool get isSpeaking => _isSpeaking;

  /// Current volume (0.0 - 1.0).
  double get volume => _volume;

  /// Current speech rate (0.0 - 1.0).
  double get rate => _rate;

  /// Initialize the TTS service.
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Set up callbacks
      _tts.setStartHandler(() {
        _isSpeaking = true;
        onStart?.call();
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        onComplete?.call();
      });

      _tts.setErrorHandler((message) {
        _isSpeaking = false;
        onError?.call(message);
      });

      _tts.setCancelHandler(() {
        _isSpeaking = false;
      });

      // Configure TTS
      await _tts.setLanguage(_language);
      await _tts.setVolume(_volume);
      await _tts.setSpeechRate(_rate);
      await _tts.setPitch(_pitch);

      // Check if language is available
      final languages = await _tts.getLanguages;
      final hasIndonesian = (languages as List).any((lang) =>
          lang.toString().toLowerCase().contains('id'));

      if (!hasIndonesian) {
        // Fallback to English if Indonesian not available
        _language = 'en-US';
        await _tts.setLanguage(_language);
      }

      _isInitialized = true;
      return true;
    } catch (e) {
      onError?.call('Gagal inisialisasi TTS: $e');
      return false;
    }
  }

  /// Speak the given text.
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (text.isEmpty) return;

    try {
      await _tts.speak(text);
    } catch (e) {
      onError?.call('Gagal berbicara: $e');
    }
  }

  /// Stop speaking.
  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  /// Pause speaking (if supported).
  Future<void> pause() async {
    await _tts.pause();
  }

  /// Set volume (0.0 - 1.0).
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _tts.setVolume(_volume);
  }

  /// Set speech rate (0.0 - 1.0).
  Future<void> setRate(double rate) async {
    _rate = rate.clamp(0.0, 1.0);
    await _tts.setSpeechRate(_rate);
  }

  /// Set pitch (0.5 - 2.0).
  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    await _tts.setPitch(_pitch);
  }

  /// Set language.
  Future<void> setLanguage(String language) async {
    _language = language;
    await _tts.setLanguage(_language);
  }

  /// Get available languages.
  Future<List<String>> getLanguages() async {
    final languages = await _tts.getLanguages;
    return (languages as List).map((e) => e.toString()).toList();
  }

  /// Dispose resources.
  void dispose() {
    _tts.stop();
  }
}

/// Helper to create voice feedback messages.
class VoiceFeedbackMessages {
  VoiceFeedbackMessages._();

  // Success messages
  static String itemAdded(String item, int qty) =>
      '$qty $item ditambahkan';

  static String itemRemoved(String item) =>
      '$item dihapus dari keranjang';

  static String qtyChanged(String item, int qty) =>
      '$item diubah jadi $qty';

  static String cartCleared() =>
      'Keranjang dikosongkan';

  static String undone() =>
      'Dibatalkan';

  static String checkoutSuccess(num total) =>
      'Pembayaran berhasil. Total ${_formatRupiah(total)}';

  static String total(num amount, int itemCount) =>
      'Total $itemCount item. ${_formatRupiah(amount)}';

  static String cartContents(List<String> items) {
    if (items.isEmpty) return 'Keranjang kosong';
    return 'Di keranjang ada ${items.join(", ")}';
  }

  // Error messages
  static String itemNotFound(String item) =>
      '$item tidak ditemukan di katalog';

  static String outOfStock(String item) =>
      '$item habis';

  static String insufficientStock(String item, int available) =>
      'Stok $item hanya $available';

  static String accessDenied() =>
      'Akses ditolak untuk perintah ini';

  static String unknownCommand() =>
      'Maaf, saya tidak mengerti. Coba ucapkan "bantuan" untuk daftar perintah';

  static String networkError() =>
      'Masalah koneksi. Coba lagi';

  static String _formatRupiah(num amount) {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
    return 'Rp $formatted';
  }
}
