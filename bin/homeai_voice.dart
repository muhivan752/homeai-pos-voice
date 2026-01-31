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
void main() async {
  // === CONFIGURATION ===
  // Set true untuk mock (demo tanpa server)
  // Set false untuk ERPNext REAL
  const useMock = true;

  // === INFRASTRUCTURE LAYER ===
  final IntentPort erpAdapter;

  if (useMock) {
    erpAdapter = MockERPNextAdapter();
    print('[MODE] Mock - tanpa ERPNext server\n');
  } else {
    // TODO: Load config dari environment/file
    final config = ERPNextConfig(
      baseUrl: 'http://localhost:8000',
      apiKey: 'YOUR_API_KEY',
      apiSecret: 'YOUR_API_SECRET',
      posProfile: 'POS-001',
      warehouse: 'Stores - ABC',
    );
    erpAdapter = ERPNextAdapter(config);
    print('[MODE] ERPNext REAL - ${config.baseUrl}\n');
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

  // === DEMO: Simulate voice commands ===
  print('=== HomeAI POS Voice Demo ===\n');

  await screen.onVoiceInput('jual kopi susu 2');
  await screen.onVoiceInput('jual es teh 1');
  await screen.onVoiceInput('bayar');
  await screen.onVoiceInput('perintah tidak dikenal xyz');

  print('\n=== Demo selesai ===');
}
