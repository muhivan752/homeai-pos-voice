import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../models/product.dart';
import '../services/barista_parser.dart';
import '../services/barista_response.dart';
import '../services/stt_corrector.dart';
import 'cart_provider.dart';
import 'customer_provider.dart';
import 'tax_provider.dart';

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
  final SttCorrector _corrector = SttCorrector();

  VoiceStatus _status = VoiceStatus.idle;
  String _lastWords = '';
  String _statusMessage = 'Tekan mic atau ketik perintah';
  bool _isAvailable = false;
  double _lastConfidence = 0.0;
  bool _hasIdLocale = false;
  String? _bestLocaleId; // best Indonesian locale found (id_ID, in_ID, or null)
  bool _showedLocaleWarning = false;

  // For auto-stop: stored so _onStatus can auto-process
  CartProvider? _activeCart;
  CustomerProvider? _activeCustomer;
  TaxProvider? _activeTax;
  bool _manualStop = false;

  VoiceStatus get status => _status;
  String get lastWords => _lastWords;
  String get statusMessage => _statusMessage;
  bool get isListening => _status == VoiceStatus.listening;
  bool get isAvailable => _isAvailable;
  bool get hasIdLocale => _hasIdLocale;

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
        try {
          final locales = await _speech.locales();
          // Try to find the best Indonesian locale
          // Priority: id_ID > in_ID > id > in > null
          for (final locale in locales) {
            final lid = locale.localeId;
            if (lid == 'id_ID' || lid == 'id-ID') {
              _bestLocaleId = lid;
              _hasIdLocale = true;
              break;
            }
            if (lid == 'in_ID' || lid == 'in-ID') {
              _bestLocaleId = lid;
              _hasIdLocale = true;
              // Don't break — keep looking for id_ID
            }
            if (_bestLocaleId == null && (lid.startsWith('id') || lid.startsWith('in'))) {
              _bestLocaleId = lid;
              _hasIdLocale = true;
            }
          }
          if (_bestLocaleId != null) {
            debugPrint('[POS Voice] Indonesian locale found: $_bestLocaleId');
          } else {
            debugPrint('[POS Voice] No Indonesian locale — will use device default');
          }
        } catch (_) {
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
    } else if (status == 'done' || status == 'notListening') {
      // Auto-stop: speech engine stopped on its own (user finished talking)
      // Only auto-process if NOT manually stopped by button press
      if (_status == VoiceStatus.listening && !_manualStop) {
        debugPrint('[POS Voice] Auto-stopped by speech engine');
        if (_lastWords.isNotEmpty && _activeCart != null) {
          // Auto-process the captured text
          _status = VoiceStatus.processing;
          _statusMessage = 'Bentar ya...';
          notifyListeners();
          // Use Future.microtask to let speech engine finish cleanup
          Future.microtask(() {
            final text = _lastWords;
            final cart = _activeCart;
            final customer = _activeCustomer;
            final tax = _activeTax;
            _activeCart = null;
            _activeCustomer = null;
            _activeTax = null;
            if (text.isNotEmpty && cart != null) {
              processText(text, cart, customerProvider: customer, taxProvider: tax);
            }
          });
        } else {
          _status = VoiceStatus.idle;
          _statusMessage = 'Gak kedengeran nih, coba lagi atau ketik aja!';
          _activeCart = null;
          _activeCustomer = null;
          _activeTax = null;
          notifyListeners();
        }
      }
    }
  }

  void _onError(dynamic error) {
    _status = VoiceStatus.error;
    _activeCart = null;
    _activeCustomer = null;
    _activeTax = null;
    _manualStop = false;

    final msg = error.errorMsg?.toString() ?? '';
    debugPrint('[POS Voice] STT error: $msg');
    if (msg.contains('error_no_match')) {
      _statusMessage = 'Gak kedengeran nih. Coba dekatkan ke mulut atau ketik aja!';
    } else if (msg.contains('error_speech_timeout')) {
      _statusMessage = 'Kelamaan diem nih. Tekan mic lalu langsung ngomong ya!';
    } else if (msg.contains('error_audio')) {
      _statusMessage = 'Mic bermasalah. Cek permission mic di Settings, atau ketik aja!';
    } else if (msg.contains('error_network')) {
      _statusMessage = 'Perlu internet untuk voice. Cek koneksi atau pakai ketik!';
    } else if (msg.contains('error_permission') || msg.contains('error_not_allowed')) {
      _statusMessage = 'Izin mic belum diberikan. Buka Settings > Permissions > Microphone';
    } else {
      _statusMessage = 'Voice error ($msg). Coba ketik aja ya!';
    }
    notifyListeners();

    Future.delayed(const Duration(seconds: 4), () {
      if (_status == VoiceStatus.error) {
        _status = VoiceStatus.idle;
        _statusMessage = 'Tekan mic atau ketik perintah';
        notifyListeners();
      }
    });
  }

  /// Start listening. Pass providers so auto-stop can process.
  Future<void> startListening(CartProvider cartProvider, {CustomerProvider? customerProvider, TaxProvider? taxProvider}) async {
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
    _manualStop = false;
    _activeCart = cartProvider;
    _activeCustomer = customerProvider;
    _activeTax = taxProvider;
    _status = VoiceStatus.listening;

    // Show locale warning once if Indonesian not found
    if (!_hasIdLocale && !_showedLocaleWarning) {
      _showedLocaleWarning = true;
      _statusMessage = 'Bahasa Indonesia belum terinstall — voice tetap jalan, tapi mungkin kurang akurat. '
          'Install di Settings > System > Languages & input > Speech';
    } else {
      _statusMessage = 'Ngomong aja, gak perlu tekan stop...';
    }
    notifyListeners();

    final localeId = _bestLocaleId;

    try {
      await _speech.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
        localeId: localeId,
        cancelOnError: true,
        partialResults: true,
      );
    } catch (e) {
      try {
        await _speech.listen(
          onResult: _onSpeechResult,
          listenFor: const Duration(seconds: 15),
          pauseFor: const Duration(seconds: 3),
          cancelOnError: true,
          partialResults: true,
        );
      } catch (_) {
        _status = VoiceStatus.error;
        _activeCart = null;
        _activeCustomer = null;
        _activeTax = null;
        _statusMessage = 'Voice gagal start. Coba ketik aja!';
        notifyListeners();
      }
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    final words = result.recognizedWords.trim();
    if (words.isNotEmpty) {
      _lastWords = words;
      _lastConfidence = result.confidence;
      debugPrint('[POS Voice] Heard: "$words" (confidence: ${result.confidence})');
      notifyListeners();
    }
  }

  /// Manual stop — called by VoiceButton when user presses stop.
  Future<void> stopListening() async {
    _manualStop = true;
    _activeCart = null;
    _activeCustomer = null;
    _activeTax = null;
    await _speech.stop();
    _status = VoiceStatus.idle;
    notifyListeners();
  }

  Future<void> processCommand(CartProvider cartProvider, {CustomerProvider? customerProvider, TaxProvider? taxProvider}) async {
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

      final filterResult = _qualityCheck(_lastWords, _lastConfidence);
      if (filterResult != null) {
        debugPrint('[POS Voice] Quality filter rejected: $filterResult');
        _statusMessage = filterResult;
        return;
      }

      final result = await _executeBarista(_lastWords, cartProvider, customerProvider: customerProvider, taxProvider: taxProvider);
      debugPrint('[POS Voice] Result: $result');
      _statusMessage = result;
    } catch (e, stackTrace) {
      debugPrint('[POS Voice] ERROR in processCommand: $e');
      debugPrint('[POS Voice] Stack: $stackTrace');
      _statusMessage = 'Waduh error nih. Coba lagi atau ketik aja!';
    } finally {
      _status = VoiceStatus.idle;
      notifyListeners();
    }
  }

  String? _qualityCheck(String text, double confidence) {
    final lower = text.toLowerCase().trim();

    if (lower.length < 3) {
      return 'Terlalu pendek nih, coba ngomong lebih jelas ya!';
    }

    if (_noiseWords.contains(lower)) {
      return 'Gak nangkep yang jelas, coba bilang lagi?';
    }

    // Don't block English — the STT corrector will translate it
    // Only warn if it's heavily English (4+ indicators) AND very short
    if (_looksEnglish(lower) && lower.split(' ').length <= 2) {
      return 'Hmm, coba ngomong lebih lengkap ya!';
    }

    if (confidence > 0 && confidence < 0.3) {
      return 'Kurang jelas nih, bisa diulang? Atau ketik aja!';
    }

    return null;
  }

  bool _looksEnglish(String lower) {
    int englishHits = 0;
    for (final indicator in _englishIndicators) {
      if (lower.contains(indicator)) {
        englishHits++;
      }
    }
    return englishHits >= 3;
  }

  Future<String> _executeBarista(String text, CartProvider cartProvider, {CustomerProvider? customerProvider, TaxProvider? taxProvider}) async {
    // Run STT corrector BEFORE parsing
    final corrected = _corrector.correct(text);
    debugPrint('[POS Voice] Original: "$text" → Corrected: "$corrected"');
    final textToParse = corrected.isNotEmpty ? corrected : text;
    final result = _parser.parse(textToParse);
    debugPrint('[POS Voice] Intent: ${result.intent}, product: ${result.product?.name}, qty: ${result.quantity}, customerName: ${result.customerName}');
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
            final subtotal = cartProvider.total;
            final tax = taxProvider?.calculate(subtotal);
            final txId = await cartProvider.checkoutWithPayment(
              paymentMethod: result.paymentMethod!,
              customerName: customerProvider?.customerName,
              customerId: customerProvider?.activeCustomer?.id,
              subtotal: subtotal,
              taxPb1: tax?.pb1Amount ?? 0,
              taxPpn: tax?.ppnAmount ?? 0,
            );
            // Record customer visit after successful checkout
            if (txId != null && customerProvider?.hasCustomer == true) {
              await customerProvider!.recordVisit(txId);
            }
          }
        }
        break;

      case BaristaIntent.clearCart:
        cartProvider.clearCart();
        _parser.clearContext();
        break;

      case BaristaIntent.identifyCustomer:
        if (customerProvider != null && result.customerName != null) {
          // Try to find existing customer
          final existing = await customerProvider.recognizeByName(result.customerName!);
          if (existing == null) {
            // Register as new customer
            await customerProvider.registerCustomer(result.customerName!);
            debugPrint('[POS Voice] New customer registered: ${result.customerName}');
          } else {
            debugPrint('[POS Voice] Customer recognized: ${existing.name} (${existing.visitCount} visits)');
          }
        }
        break;

      case BaristaIntent.orderBiasa:
        if (customerProvider != null && customerProvider.hasBiasa) {
          // Add the customer's favorite item to cart
          final biasa = customerProvider.yangBiasa!;
          final product = Product.sampleProducts.where(
            (p) => p.id == biasa.productId || p.name == biasa.productName,
          ).firstOrNull;

          if (product != null) {
            cartProvider.addItem(product, 1);
            _parser.setLastProduct(product);
            debugPrint('[POS Voice] Added biasa: ${product.name}');
          }
        }
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
      activeCustomer: customerProvider?.activeCustomer,
      yangBiasa: customerProvider?.yangBiasa,
    );
    debugPrint('[POS Voice] Response: $response');
    return response;
  }

  /// Process a text command directly (for text input or auto-stop).
  Future<String> processText(String text, CartProvider cartProvider, {CustomerProvider? customerProvider, TaxProvider? taxProvider}) async {
    _lastWords = text;
    _status = VoiceStatus.processing;
    notifyListeners();

    try {
      debugPrint('[POS Voice] Processing text: "$text"');
      final result = await _executeBarista(text, cartProvider, customerProvider: customerProvider, taxProvider: taxProvider);
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
    _activeCart = null;
    _activeCustomer = null;
    _activeTax = null;
    _manualStop = false;
    _parser.clearContext();
    notifyListeners();
  }
}
