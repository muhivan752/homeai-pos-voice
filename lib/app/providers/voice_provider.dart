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
  String _statusMessage = 'Tekan tombol mic untuk mulai';
  bool _isAvailable = false;

  VoiceStatus get status => _status;
  String get lastWords => _lastWords;
  String get statusMessage => _statusMessage;
  bool get isListening => _status == VoiceStatus.listening;
  bool get isAvailable => _isAvailable;

  Future<bool> initialize() async {
    try {
      _isAvailable = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
      );

      if (_isAvailable) {
        _statusMessage = 'Siap menerima perintah suara';
      } else {
        _statusMessage = 'Speech recognition tidak tersedia';
      }
      notifyListeners();
      return _isAvailable;
    } catch (e) {
      _statusMessage = 'Error: ${e.toString()}';
      _status = VoiceStatus.error;
      notifyListeners();
      return false;
    }
  }

  void _onStatus(String status) {
    if (status == 'listening') {
      _status = VoiceStatus.listening;
      _statusMessage = 'Dengerin nih...';
    } else if (status == 'done' || status == 'notListening') {
      if (_status == VoiceStatus.listening) {
        _status = VoiceStatus.processing;
        _statusMessage = 'Bentar ya...';
      }
    }
    notifyListeners();
  }

  void _onError(dynamic error) {
    _status = VoiceStatus.error;
    _statusMessage = 'Waduh, error nih: ${error.errorMsg}';
    notifyListeners();

    Future.delayed(const Duration(seconds: 2), () {
      _status = VoiceStatus.idle;
      _statusMessage = 'Coba lagi yuk, tekan mic-nya';
      notifyListeners();
    });
  }

  Future<void> startListening() async {
    if (!_isAvailable) {
      await initialize();
    }

    if (!_isAvailable) {
      _statusMessage = 'Speech recognition tidak tersedia';
      return;
    }

    _lastWords = '';
    _status = VoiceStatus.listening;
    _statusMessage = 'Dengerin nih...';
    notifyListeners();

    await _speech.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      localeId: 'id_ID',
      cancelOnError: true,
      partialResults: true,
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    _lastWords = result.recognizedWords;
    notifyListeners();
  }

  Future<void> stopListening() async {
    await _speech.stop();
    _status = VoiceStatus.idle;
    _statusMessage = 'Tekan mic kalau mau pesan lagi';
    notifyListeners();
  }

  void processCommand(CartProvider cartProvider) {
    if (_lastWords.isEmpty) {
      _statusMessage = 'Gak kedengeran nih, coba lagi ya?';
      _status = VoiceStatus.idle;
      notifyListeners();
      return;
    }

    _status = VoiceStatus.processing;
    _statusMessage = 'Bentar ya...';
    notifyListeners();

    final result = _executeBarista(_lastWords, cartProvider);

    _statusMessage = result;
    _status = VoiceStatus.idle;
    notifyListeners();
  }

  /// Process voice input through BaristaParser + BaristaResponse.
  String _executeBarista(String text, CartProvider cartProvider) {
    // Parse the command
    final result = _parser.parse(text);
    final isFirstItem = cartProvider.itemCount == 0;

    // Execute the intent
    switch (result.intent) {
      case BaristaIntent.addItem:
        if (result.product != null) {
          cartProvider.addItem(result.product!, result.quantity);
          _parser.setLastProduct(result.product!);
        }
        break;

      case BaristaIntent.removeItem:
        if (result.product != null) {
          // Find matching item in cart and remove it
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
          // If payment method detected, do full checkout
          if (result.paymentMethod != null) {
            cartProvider.checkoutWithPayment(
              paymentMethod: result.paymentMethod!,
            );
          }
          // Otherwise just signal — UI will show payment screen
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
        // No cart action needed
        break;
    }

    // Generate fun response
    return _responder.respond(
      result: result,
      cartItemCount: cartProvider.itemCount,
      cartTotal: cartProvider.total,
      isFirstItem: isFirstItem,
    );
  }

  /// Process a text command directly (for testing or text input).
  String processText(String text, CartProvider cartProvider) {
    _lastWords = text;
    return _executeBarista(text, cartProvider);
  }

  void reset() {
    _lastWords = '';
    _status = VoiceStatus.idle;
    _statusMessage = 'Tekan mic kalau mau pesan';
    _parser.clearContext();
    notifyListeners();
  }
}
