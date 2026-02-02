import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'application/intent_executor.dart';
import 'application/pos_voice_service.dart';
import 'domain/domain.dart';
import 'infrastructure/auth/auth_context.dart';
import 'infrastructure/auth/role_gatekeeper.dart';
import 'infrastructure/erp/mock_erpnext_adapter.dart';
import 'infrastructure/events/events.dart';
import 'infrastructure/intent_parser.dart';
import 'infrastructure/voice/voice.dart';
import 'presentation/providers/pos_provider.dart';
import 'presentation/screens/screens.dart';
import 'presentation/theme/pos_theme.dart';

void main() {
  runApp(const HomeAiPosApp());
}

/// HomeAI POS Voice App.
///
/// Phase 2: Tablet UI with Customer + Staff modes.
class HomeAiPosApp extends StatelessWidget {
  const HomeAiPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HomeAI POS',
      theme: PosTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const PosEntryPoint(),
    );
  }
}

/// Entry point that handles role selection and navigation.
class PosEntryPoint extends StatefulWidget {
  const PosEntryPoint({super.key});

  @override
  State<PosEntryPoint> createState() => _PosEntryPointState();
}

class _PosEntryPointState extends State<PosEntryPoint> {
  AuthContext? _currentAuth;
  PosProvider? _provider;

  // Dependencies (created once)
  late final ERPPort _erpAdapter;
  late final EventLogger _logger;
  late final IntentParser _parser;
  late final RoleGatekeeper _gatekeeper;

  @override
  void initState() {
    super.initState();
    _initializeDependencies();
  }

  void _initializeDependencies() {
    // Create shared dependencies
    // In production, switch to ERPNextAdapter based on config
    _erpAdapter = MockERPNextAdapter();
    _logger = EventLogger(debugMode: true);
    _parser = IntentParser();
    _gatekeeper = RoleGatekeeper();
  }

  void _onRoleSelected(AuthContext auth) {
    // Create service and provider for this session
    final executor = IntentExecutor(_erpAdapter);
    final service = PosVoiceService(
      parser: _parser,
      executor: executor,
      gatekeeper: _gatekeeper,
      auth: auth,
    );

    final speech = SpeechService();
    final tts = TtsService();

    final provider = PosProvider(
      service: service,
      logger: _logger,
      speech: speech,
      tts: tts,
      auth: auth,
    );

    // Initialize provider
    provider.initialize();

    setState(() {
      _currentAuth = auth;
      _provider = provider;
    });
  }

  void _onLogout() {
    _provider?.dispose();
    setState(() {
      _currentAuth = null;
      _provider = null;
    });
  }

  @override
  void dispose() {
    _provider?.dispose();
    _logger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No auth yet - show role selection
    if (_currentAuth == null || _provider == null) {
      return RoleSelectionScreen(
        onRoleSelected: _onRoleSelected,
      );
    }

    // Provide state to widget tree
    return ChangeNotifierProvider<PosProvider>.value(
      value: _provider!,
      child: _buildScreen(),
    );
  }

  Widget _buildScreen() {
    final auth = _currentAuth!;

    // Customer mode
    if (auth.role == UserRole.customer) {
      return CustomerScreen(
        service: _buildService(auth),
        onExit: _onLogout,
      );
    }

    // Staff mode (barista, spv, owner)
    return StaffScreen(
      service: _buildService(auth),
      auth: auth,
      onLogout: _onLogout,
    );
  }

  PosVoiceService _buildService(AuthContext auth) {
    return PosVoiceService(
      parser: _parser,
      executor: IntentExecutor(_erpAdapter),
      gatekeeper: _gatekeeper,
      auth: auth,
    );
  }
}
