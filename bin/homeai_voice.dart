import 'dart:io';

import '../lib/intent/intent_port.dart';
import '../lib/infrastructure/intent_parser.dart';
import '../lib/application/intent_executor.dart';
import '../lib/infrastructure/auth/auth_context.dart';
import '../lib/infrastructure/auth/role_gatekeeper.dart';
import '../lib/infrastructure/erp/mock_erpnext_adapter.dart';
import '../lib/infrastructure/erp/erpnext_adapter.dart';
import '../lib/infrastructure/erp/erpnext_config.dart';
import '../lib/application/pos_voice_service.dart';
import '../lib/ui/pos_screen.dart';

/// ENTRYPOINT - Satu-satunya tempat wiring dependency.
///
/// ATURAN ARSITEKTUR:
/// 1. Semua dependency di-create di sini
/// 2. IntentPort implementation di-inject ke executor
/// 3. PosVoiceService di-inject ke UI
/// 4. UI TIDAK BOLEH tahu tentang Parser, Executor, atau ERP adapter
///
/// USAGE:
///   Mock mode:  dart run
///   Real mode:  source .env && USE_MOCK=false dart run
void main() async {
  // === CONFIGURATION ===
  final useMock = Platform.environment['USE_MOCK']?.toLowerCase() != 'false';

  // === INFRASTRUCTURE LAYER ===
  final IntentPort erpAdapter;

  if (useMock) {
    erpAdapter = MockERPNextAdapter();
    print('[MODE] Mock - tanpa ERPNext server\n');
  } else {
    try {
      final config = ERPNextConfig.fromEnv();
      erpAdapter = ERPNextAdapter(config);
      print('[MODE] ERPNext REAL - ${config.baseUrl}\n');
    } on ConfigError catch (e) {
      print('[ERROR] $e');
      print('[HINT] Copy .env.example to .env and fill in your values');
      print('[HINT] Then run: source .env && USE_MOCK=false dart run');
      exit(1);
    }
  }

  // Parser dan Executor
  final parser = IntentParser();
  final executor = IntentExecutor(erpAdapter);

  // Auth
  final auth = AuthContext(UserRole.barista);
  final gatekeeper = RoleGatekeeper();

  // === APPLICATION LAYER ===
  final service = PosVoiceService(
    parser: parser,
    executor: executor,
    gatekeeper: gatekeeper,
    auth: auth,
  );

  // === UI LAYER ===
  final screen = PosScreen(service: service);

  // === DEMO: Phase 1 - Core Voice Commerce ===
  print('=== HomeAI POS Voice - Phase 1 Demo ===\n');

  // Add items
  await screen.onVoiceInput('jual kopi susu 2');
  await screen.onVoiceInput('tambah es teh 1');
  await screen.onVoiceInput('pesan americano');

  // Read cart
  await screen.onVoiceInput('isi keranjang');
  await screen.onVoiceInput('totalnya berapa');

  // Modify cart
  await screen.onVoiceInput('kopi susu jadi 3');
  await screen.onVoiceInput('batal es teh');
  await screen.onVoiceInput('total');

  // Undo
  await screen.onVoiceInput('undo');
  await screen.onVoiceInput('keranjang');

  // Checkout
  await screen.onVoiceInput('bayar');

  // Help
  await screen.onVoiceInput('bantuan');

  // Unknown
  await screen.onVoiceInput('perintah aneh xyz');

  print('\n=== Demo selesai ===');
}
