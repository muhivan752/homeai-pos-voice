import '../lib/intent/intent_port.dart';
import '../lib/infrastructure/intent_parser.dart';
import '../lib/infrastructure/intent_executor.dart';
import '../lib/infrastructure/auth/auth_context.dart';
import '../lib/infrastructure/auth/role_gatekeeper.dart';
import '../lib/infrastructure/erp/erpnext_adapter.dart';
import '../lib/application/pos_voice_service.dart';
import '../lib/ui/pos_screen.dart';

/// ENTRYPOINT - Satu-satunya tempat wiring dependency.
///
/// ATURAN ARSITEKTUR:
/// 1. Semua dependency di-create di sini
/// 2. IntentPort implementation (ERPNextAdapter) di-inject ke executor
/// 3. PosVoiceService di-inject ke UI
/// 4. UI TIDAK BOLEH tahu tentang Parser, Executor, atau ERP adapter
void main() async {
  // === CONFIGURATION ===
  // TODO: Load dari environment variables atau config file
  final erpConfig = _loadERPConfig();

  // === INFRASTRUCTURE LAYER ===
  // ERP adapter implements IntentPort
  final IntentPort erpAdapter = ERPNextAdapter(
    baseUrl: erpConfig.baseUrl,
    apiKey: erpConfig.apiKey,
    apiSecret: erpConfig.apiSecret,
  );

  // Parser dan Executor
  final parser = IntentParser();
  final executor = IntentExecutor(erpAdapter);

  // Auth
  final auth = AuthContext(UserRole.barista); // TODO: dari login session
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

/// Load ERP configuration.
/// TODO: Implement proper config loading from env/file.
_ERPConfig _loadERPConfig() {
  return _ERPConfig(
    baseUrl: 'http://localhost:8000',
    apiKey: 'demo-api-key',
    apiSecret: 'demo-api-secret',
  );
}

class _ERPConfig {
  final String baseUrl;
  final String apiKey;
  final String apiSecret;

  _ERPConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.apiSecret,
  });
}
