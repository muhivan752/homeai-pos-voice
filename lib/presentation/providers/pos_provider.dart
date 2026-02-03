import 'package:flutter/foundation.dart';
import '../../application/pos_voice_service.dart';
import '../../domain/domain.dart';
import '../../infrastructure/auth/auth_context.dart';
import '../../infrastructure/events/events.dart';
import '../../infrastructure/voice/voice.dart';

/// State for voice input.
enum VoiceState {
  idle,
  listening,
  processing,
  success,
  error,
}

/// Provider for POS state management.
///
/// Wraps PosVoiceService and provides:
/// - Cart state
/// - Voice state
/// - Event logging
/// - Speech/TTS integration
class PosProvider extends ChangeNotifier {
  final PosVoiceService _service;
  final EventLogger _logger;
  final SpeechService _speech;
  final TtsService _tts;
  AuthContext _auth;

  // Cart state
  List<CartItem> _cartItems = [];
  CartTotal? _cartTotal;

  // Voice state
  VoiceState _voiceState = VoiceState.idle;
  String? _recognizedText;
  String? _feedbackMessage;
  bool _feedbackIsError = false;

  // Initialization state
  bool _isInitialized = false;
  bool _isSpeechAvailable = false;

  PosProvider({
    required PosVoiceService service,
    required EventLogger logger,
    required SpeechService speech,
    required TtsService tts,
    required AuthContext auth,
  })  : _service = service,
        _logger = logger,
        _speech = speech,
        _tts = tts,
        _auth = auth {
    _setupSpeechListeners();
  }

  // === GETTERS ===

  List<CartItem> get cartItems => List.unmodifiable(_cartItems);
  CartTotal? get cartTotal => _cartTotal;
  VoiceState get voiceState => _voiceState;
  String? get recognizedText => _recognizedText;
  String? get feedbackMessage => _feedbackMessage;
  bool get feedbackIsError => _feedbackIsError;
  bool get isInitialized => _isInitialized;
  bool get isSpeechAvailable => _isSpeechAvailable;
  AuthContext get auth => _auth;
  EventLogger get logger => _logger;

  // === INITIALIZATION ===

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize speech with timeout
      _isSpeechAvailable = await _speech.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () => false,
      );
    } catch (e) {
      _isSpeechAvailable = false;
    }

    try {
      // Initialize TTS with timeout
      await _tts.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () => false,
      );
    } catch (e) {
      // TTS initialization failed, continue without TTS
    }

    _isInitialized = true;
    notifyListeners();

    // Log session start
    _logger.log(PosEvent.sessionStarted(role: _auth.role));
  }

  void _setupSpeechListeners() {
    _speech.resultStream.listen((result) {
      _recognizedText = result.text;
      notifyListeners();

      if (result.isFinal) {
        _handleCommand(result.text);
      }
    });

    _speech.statusStream.listen((status) {
      switch (status) {
        case SpeechStatus.listening:
          _voiceState = VoiceState.listening;
          break;
        case SpeechStatus.done:
        case SpeechStatus.stopped:
          if (_voiceState == VoiceState.listening) {
            _voiceState = VoiceState.idle;
          }
          break;
        case SpeechStatus.error:
          _voiceState = VoiceState.error;
          break;
        default:
          break;
      }
      notifyListeners();
    });
  }

  // === AUTH ===

  void updateAuth(AuthContext auth) {
    _auth = auth;

    // Log mode change
    _logger.log(PosEvent.modeChanged(
      fromMode: _auth.role.name,
      toMode: auth.role.name,
    ));

    notifyListeners();
  }

  // === VOICE ===

  Future<void> startListening() async {
    if (!_isSpeechAvailable) return;

    _recognizedText = null;
    _feedbackMessage = null;
    _voiceState = VoiceState.listening;
    notifyListeners();

    await _speech.startListening();
  }

  Future<void> stopListening() async {
    await _speech.stopListening();
    _voiceState = VoiceState.idle;
    notifyListeners();
  }

  Future<void> cancelListening() async {
    await _speech.cancelListening();
    _voiceState = VoiceState.idle;
    _recognizedText = null;
    notifyListeners();
  }

  // === COMMANDS ===

  Future<void> handleCommand(String command) async {
    await _handleCommand(command);
  }

  Future<void> _handleCommand(String command) async {
    _voiceState = VoiceState.processing;
    _recognizedText = command;
    notifyListeners();

    // Log voice input
    _logger.log(PosEvent.voiceInput(
      rawInput: command,
      success: true,
      role: _auth.role,
    ));

    // Execute command
    final result = await _service.handleVoice(command);

    // Update feedback
    _feedbackMessage = result.message;
    _feedbackIsError = !result.isSuccess;
    _voiceState = result.isSuccess ? VoiceState.success : VoiceState.error;
    notifyListeners();

    // Speak feedback
    await _tts.speak(result.message);

    // Auto-reset after delay
    Future.delayed(const Duration(seconds: 3), () {
      if (_voiceState == VoiceState.success ||
          _voiceState == VoiceState.error) {
        _voiceState = VoiceState.idle;
        notifyListeners();
      }
    });

    Future.delayed(const Duration(seconds: 5), () {
      _recognizedText = null;
      _feedbackMessage = null;
      notifyListeners();
    });
  }

  // === TTS ===

  Future<void> speak(String text) async {
    await _tts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
  }

  // === CLEANUP ===

  void clearFeedback() {
    _recognizedText = null;
    _feedbackMessage = null;
    _feedbackIsError = false;
    _voiceState = VoiceState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    // Log session end
    _logger.log(PosEvent.sessionEnded(
      role: _auth.role,
      sessionStats: _logger.getSessionStats(),
    ));

    _speech.dispose();
    _tts.dispose();
    _logger.dispose();
    super.dispose();
  }
}
