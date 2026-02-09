import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../models/product.dart';
import '../services/barista_parser.dart';
import '../services/barista_response.dart';
import 'cart_provider.dart';

enum VoiceStatus {
  idle,
  listening,
  processing,
  error,
}

class VoiceProvider extends ChangeNotifier {
  final SpeechToText _speech = SpeechToText();
  final BaristaParser _parser = BaristaParser();
  final BaristaResponse _responder = BaristaResponse();

  VoiceStatus _status = VoiceStatus.idle;
  String _lastWords = '';
  String _statusMessage = 'Tekan mic atau ketik perintah';
  bool _isAvailable = false;
  double _lastConfidence = 0.0;
  bool _hasIdLocale = false;

  VoiceStatus get status => _status;
  String get lastWords => _lastWords;
  String get statusMessage => _statusMessage;
  bool get isListening => _status == VoiceStatus.listening;
  bool get isAvailable => _isAvailable;

  /// Common English words that indicate wrong language detection.
  static const _englishIndicators = [
    'i ', 'you ', 'the ', 'is ', 'are ', 'was ', 'were ',
    'have ', 'has ', 'had ', 'will ', 'would ', 'could ',
    'should ', 'said ', 'what ', 'when ', 'where ', 'which ',
    'that ', 'this ', 'with ', 'from ', 'they ', 'been ',
    'call ', 'first ', 'who ', 'may ', 'its ', 'like ',
    'him ', 'her ', 'make ', 'can ', "don't", "i'm ",
  ];

  /// Very short words that are likely noise, not real commands.
  static const _noiseWords = [
    'ya', 'ye', 'yo', 'ha', 'he', 'hi', 'ho', 'hu',
    'ah', 'eh', 'oh', 'uh', 'ok', 'a', 'e', 'i', 'o', 'u',
  ];

  Future<bool> initialize() async {
    try {
      _isAvailable = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
      );

      if (_isAvailable) {
        // Check if Indonesian locale is explicitly listed
        try {
          final locales = await _speech.locales();
          _hasIdLocale = locales.any(
            (l) => l.localeId.startsWith('id') || l.localeId.startsWith('in'),
          );
        } catch (_) {
          // Some devices fail to list locales — that's fine, still allow voice
          _hasIdLocale = false;
        }
        _statusMessage = 'Siap! Tekan mic atau ketik perintah';
      } else {
        _statusMessage = 'Voice gak tersedia. Pakai ketik aja!';
      }
      notifyListeners();
      return _isAvailable;
    } catch (e) {
      _statusMessage = 'Voice error, pakai ketik aja ya!';
      _status = VoiceStatus.error;
      notifyListeners();
      return false;
    }
  }

  void _onStatus(String status) {
    if (status == 'listening') {
      _status = VoiceStatus.listening;
      _statusMessage = 'Dengerin nih...';
      notifyListeners();
    }
    // Don't auto-set processing on 'done' — let VoiceButton handle
    // the flow manually via stopListening() + processText().
    // Auto-setting processing here caused race conditions.
  }

  void _onError(dynamic error) {
    _status = VoiceStatus.error;

    final msg = error.errorMsg?.toString() ?? '';
    if (msg.contains('error_no_match')) {
      _statusMessage = 'Gak kedengeran nih. Coba lagi atau ketik aja!';
    } else if (msg.contains('error_speech_timeout')) {
      _statusMessage = 'Kelamaan diem nih. Coba lagi?';
    } else {
      _statusMessage = 'Voice error, coba ketik aja ya!';
    }
    notifyListeners();

    Future.delayed(const Duration(seconds: 3), () {
      _status = VoiceStatus.idle;
      _statusMessage = 'Tekan mic atau ketik perintah';
      notifyListeners();
    });
  }

  Future<void> startListening() async {
    if (!_isAvailable) {
      await initialize();
    }

    if (!_isAvailable) {
      _statusMessage = 'Voice gak tersedia, ketik aja ya!';
      notifyListeners();
      return;
    }

    _lastWords = '';
    _lastConfidence = 0.0;
    _status = VoiceStatus.listening;
    _statusMessage = 'Dengerin nih... ngomong yang jelas ya!';
    notifyListeners();

    // Try id_ID first, fall back to device default if not found
    final localeId = _hasIdLocale ? 'id_ID' : null;

    try {
      await _speech.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        localeId: localeId,
        cancelOnError: true,
        partialResults: true,
      );
    } catch (e) {
      // If locale fails, retry without specifying locale
      try {
        await _speech.listen(
          onResult: _onSpeechResult,
          listenFor: const Duration(seconds: 10),
          pauseFor: const Duration(seconds: 3),
          cancelOnError: true,
          partialResults: true,
        );
      } catch (_) {
        _status = VoiceStatus.error;
        _statusMessage = 'Voice gagal start. Coba ketik aja!';
        notifyListeners();
      }
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    // Only update if we got actual text — speech engine sometimes
    // sends a final empty callback that would clear our captured text
    final words = result.recognizedWords.trim();
    if (words.isNotEmpty) {
      _lastWords = words;
      _lastConfidence = result.confidence;
      debugPrint('[POS Voice] Heard: "$words" (confidence: ${result.confidence})');
      notifyListeners();
    }
  }

  Future<void> stopListening() async {
    await _speech.stop();
    _status = VoiceStatus.idle;
    _statusMessage = 'Tekan mic atau ketik perintah';
    notifyListeners();
  }

  void processCommand(CartProvider cartProvider) {
    if (_lastWords.isEmpty) {
      _statusMessage = 'Gak kedengeran nih, coba lagi atau ketik aja!';
      _status = VoiceStatus.idle;
      notifyListeners();
      return;
    }

    _status = VoiceStatus.processing;
    _statusMessage = 'Bentar ya...';
    notifyListeners();

    try {
      debugPrint('[POS Voice] Processing: "$_lastWords" (confidence: $_lastConfidence)');

      // Quality filter before processing
      final filterResult = _qualityCheck(_lastWords, _lastConfidence);
      if (filterResult != null) {
        debugPrint('[POS Voice] Quality filter rejected: $filterResult');
        _statusMessage = filterResult;
        _status = VoiceStatus.idle;
        notifyListeners();
        return;
      }

      final result = _executeBarista(_lastWords, cartProvider);
      debugPrint('[POS Voice] Result: $result');
      _statusMessage = result;
    } catch (e, stackTrace) {
      debugPrint('[POS Voice] ERROR in processCommand: $e');
      debugPrint('[POS Voice] Stack: $stackTrace');
      _statusMessage = 'Waduh error nih. Coba lagi atau ketik aja!';
    } finally {
      // ALWAYS reset to idle — never stay stuck on processing
      _status = VoiceStatus.idle;
      notifyListeners();
    }
  }

  /// Check if voice result is good enough to process.
  /// Returns error message if bad, null if OK.
  String? _qualityCheck(String text, double confidence) {
    final lower = text.toLowerCase().trim();

    // Too short (likely noise)
    if (lower.length < 3) {
      return 'Terlalu pendek nih, coba ngomong lebih jelas ya!';
    }

    // Single noise word
    if (_noiseWords.contains(lower)) {
      return 'Gak nangkep yang jelas, coba bilang lagi?';
    }

    // Likely English (wrong language)
    if (_looksEnglish(lower)) {
      return 'Kayaknya kedeteksi bahasa Inggris nih. '
          'Coba pastiin bahasa Indonesia aktif di HP, atau ketik aja!';
    }

    // Very low confidence (if reported)
    if (confidence > 0 && confidence < 0.3) {
      return 'Kurang jelas nih, bisa diulang? Atau ketik aja!';
    }

    return null; // OK to process
  }

  /// Heuristic: does the text look like English?
  bool _looksEnglish(String lower) {
    int englishHits = 0;
    for (final indicator in _englishIndicators) {
      if (lower.contains(indicator)) {
        englishHits++;
      }
    }
    // If 2+ English words found, likely English
    return englishHits >= 2;
  }

  /// Process voice input through BaristaParser + BaristaResponse.
  String _executeBarista(String text, CartProvider cartProvider) {
    debugPrint('[POS Voice] Parsing: "$text"');
    final result = _parser.parse(text);
    debugPrint('[POS Voice] Intent: ${result.intent}, product: ${result.product?.name}, qty: ${result.quantity}');
    final isFirstItem = cartProvider.itemCount == 0;

    switch (result.intent) {
      case BaristaIntent.addItem:
        if (result.product != null) {
          debugPrint('[POS Voice] Adding ${result.product!.name} x${result.quantity} to cart');
          cartProvider.addItem(result.product!, result.quantity);
          _parser.setLastProduct(result.product!);
        }
        break;

      case BaristaIntent.removeItem:
        if (result.product != null) {
          final cartItems = cartProvider.items;
          final match = cartItems.where(
            (item) => item.id == result.product!.id,
          );
          if (match.isNotEmpty) {
            cartProvider.removeItem(match.first.id);
          }
        }
        break;

      case BaristaIntent.checkout:
        if (cartProvider.itemCount > 0) {
          if (result.paymentMethod != null) {
            cartProvider.checkoutWithPayment(
              paymentMethod: result.paymentMethod!,
            );
          }
        }
        break;

      case BaristaIntent.clearCart:
        cartProvider.clearCart();
        _parser.clearContext();
        break;

      case BaristaIntent.greeting:
      case BaristaIntent.thanks:
      case BaristaIntent.askMenu:
      case BaristaIntent.unknown:
        break;
    }

    debugPrint('[POS Voice] Generating response...');
    final response = _responder.respond(
      result: result,
      cartItemCount: cartProvider.itemCount,
      cartTotal: cartProvider.total,
      isFirstItem: isFirstItem,
    );
    debugPrint('[POS Voice] Response: $response');
    return response;
  }

  /// Process a text command directly (for text input fallback).
  String processText(String text, CartProvider cartProvider) {
    _lastWords = text;
    _status = VoiceStatus.processing;
    notifyListeners();

    try {
      debugPrint('[POS Voice] Text input: "$text"');
      final result = _executeBarista(text, cartProvider);
      debugPrint('[POS Voice] Result: $result');
      _statusMessage = result;
      return result;
    } catch (e, stackTrace) {
      debugPrint('[POS Voice] ERROR in processText: $e');
      debugPrint('[POS Voice] Stack: $stackTrace');
      _statusMessage = 'Waduh error nih. Coba lagi ya!';
      return _statusMessage;
    } finally {
      _status = VoiceStatus.idle;
      notifyListeners();
    }
  }

  void reset() {
    _lastWords = '';
    _status = VoiceStatus.idle;
    _statusMessage = 'Tekan mic atau ketik perintah';
    _parser.clearContext();
    notifyListeners();
  }
}
