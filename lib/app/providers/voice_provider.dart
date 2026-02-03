import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../models/product.dart';
import 'cart_provider.dart';

enum VoiceStatus {
  idle,
  listening,
  processing,
  error,
}

class VoiceProvider extends ChangeNotifier {
  final SpeechToText _speech = SpeechToText();

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
      _statusMessage = 'Mendengarkan...';
    } else if (status == 'done' || status == 'notListening') {
      if (_status == VoiceStatus.listening) {
        _status = VoiceStatus.processing;
        _statusMessage = 'Memproses...';
      }
    }
    notifyListeners();
  }

  void _onError(dynamic error) {
    _status = VoiceStatus.error;
    _statusMessage = 'Error: ${error.errorMsg}';
    notifyListeners();

    Future.delayed(const Duration(seconds: 2), () {
      _status = VoiceStatus.idle;
      _statusMessage = 'Tekan tombol mic untuk mulai';
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
    _statusMessage = 'Mendengarkan...';
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
    _statusMessage = 'Tekan tombol mic untuk mulai';
    notifyListeners();
  }

  void processCommand(CartProvider cartProvider) {
    if (_lastWords.isEmpty) {
      _statusMessage = 'Tidak ada perintah terdeteksi';
      _status = VoiceStatus.idle;
      notifyListeners();
      return;
    }

    _status = VoiceStatus.processing;
    _statusMessage = 'Memproses: "$_lastWords"';
    notifyListeners();

    final result = _parseAndExecute(_lastWords, cartProvider);

    _statusMessage = result;
    _status = VoiceStatus.idle;
    notifyListeners();
  }

  String _parseAndExecute(String text, CartProvider cartProvider) {
    final lowerText = text.toLowerCase().trim();

    // Checkout commands
    if (lowerText.contains('checkout') ||
        lowerText.contains('bayar') ||
        lowerText.contains('selesai') ||
        lowerText.contains('cek out')) {
      final success = cartProvider.checkout();
      return success ? 'Checkout berhasil!' : 'Keranjang kosong!';
    }

    // Clear cart
    if (lowerText.contains('hapus semua') ||
        lowerText.contains('kosongkan') ||
        lowerText.contains('batal semua') ||
        lowerText.contains('clear')) {
      cartProvider.clearCart();
      return 'Keranjang dikosongkan';
    }

    // Sell/Add item
    if (lowerText.contains('jual') ||
        lowerText.contains('tambah') ||
        lowerText.contains('add') ||
        lowerText.contains('pesan')) {
      return _handleSellCommand(lowerText, cartProvider);
    }

    // Try direct product name
    final product = Product.findByNameOrAlias(lowerText);
    if (product != null) {
      cartProvider.addItem(product, 1);
      return 'Ditambahkan: ${product.name} x1';
    }

    return 'Perintah tidak dikenali: "$text"';
  }

  String _handleSellCommand(String text, CartProvider cartProvider) {
    // Extract quantity
    int quantity = 1;
    final qtyMatch = RegExp(r'(\d+)').firstMatch(text);
    if (qtyMatch != null) {
      quantity = int.parse(qtyMatch.group(1)!);
    }

    // Remove command words and numbers to find product
    String productQuery = text
        .replaceAll(RegExp(r'jual|tambah|add|pesan'), '')
        .replaceAll(RegExp(r'\d+'), '')
        .trim();

    final product = Product.findByNameOrAlias(productQuery);

    if (product != null) {
      cartProvider.addItem(product, quantity);
      return 'Ditambahkan: ${product.name} x$quantity';
    }

    return 'Produk tidak ditemukan: "$productQuery"';
  }

  void reset() {
    _lastWords = '';
    _status = VoiceStatus.idle;
    _statusMessage = 'Tekan tombol mic untuk mulai';
    notifyListeners();
  }
}
