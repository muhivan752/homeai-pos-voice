import '../lib/intent/intent_port.dart';
import '../lib/infrastructure/intent_parser.dart';
import '../lib/application/intent_executor.dart';
import '../lib/infrastructure/auth/auth_context.dart';
import '../lib/infrastructure/auth/role_gatekeeper.dart';
import '../lib/infrastructure/erp/mock_erpnext_adapter.dart';
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
  // === INFRASTRUCTURE LAYER ===
  // Gunakan MockERPNextAdapter untuk demo (tanpa server)
  // Ganti ke ERPNextAdapter untuk production
  final IntentPort erpAdapter = MockERPNextAdapter();

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
