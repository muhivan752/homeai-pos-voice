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

  // === DEMO: Phase 1 - Core Voice Commerce (HARDENED) ===
  print('=== HomeAI POS Voice - Phase 1 Demo (HARDENED) ===\n');

  // ══════════════════════════════════════════════════════════════
  // TEST 1: Happy Path - Normal Operations
  // ══════════════════════════════════════════════════════════════
  print('\n--- TEST 1: Happy Path ---\n');

  // Add items
  await screen.onVoiceInput('jual kopi susu 2');
  await screen.onVoiceInput('tambah es teh 1');
  await screen.onVoiceInput('pesan americano');

  // Read cart
  await screen.onVoiceInput('isi keranjang');
  await screen.onVoiceInput('totalnya berapa');

  // ══════════════════════════════════════════════════════════════
  // TEST 2: Failure Cases - ERP Errors
  // ══════════════════════════════════════════════════════════════
  print('\n--- TEST 2: Failure Cases ---\n');

  // 2a. Unknown item (tidak ada di catalog)
  print('[TEST] Unknown item:');
  await screen.onVoiceInput('jual martabak 1');

  // 2b. Stock habis (latte = 0)
  print('[TEST] Stock habis:');
  await screen.onVoiceInput('pesan latte');

  // 2c. Stock tidak cukup (es teh sisa 4, minta 10)
  print('[TEST] Stock tidak cukup:');
  await screen.onVoiceInput('jual es teh 10');

  // 2d. Remove item yang tidak ada di cart
  print('[TEST] Remove non-existent:');
  await screen.onVoiceInput('batal cappuccino');

  // ══════════════════════════════════════════════════════════════
  // TEST 3: Undo Scope - KRITIS!
  // ══════════════════════════════════════════════════════════════
  print('\n--- TEST 3: Undo Scope (KRITIS) ---\n');

  // 3a. Undo setelah add (HARUS BERHASIL)
  print('[TEST] Undo setelah add:');
  await screen.onVoiceInput('undo');
  await screen.onVoiceInput('keranjang');

  // 3b. changeQty (ini clear undo stack)
  print('[TEST] changeQty (clears undo):');
  await screen.onVoiceInput('kopi susu jadi 3');

  // 3c. Undo setelah changeQty (HARUS GAGAL!)
  print('[TEST] Undo setelah changeQty (HARUS GAGAL):');
  await screen.onVoiceInput('undo');

  // 3d. Add lagi, lalu clear cart
  print('[TEST] clearCart (clears undo):');
  await screen.onVoiceInput('jual cappuccino 1');
  await screen.onVoiceInput('kosongkan');

  // 3e. Undo setelah clearCart (HARUS GAGAL!)
  print('[TEST] Undo setelah clearCart (HARUS GAGAL):');
  await screen.onVoiceInput('undo');

  // ══════════════════════════════════════════════════════════════
  // TEST 4: Edge Cases
  // ══════════════════════════════════════════════════════════════
  print('\n--- TEST 4: Edge Cases ---\n');

  // 4a. Checkout dengan keranjang kosong
  print('[TEST] Checkout kosong:');
  await screen.onVoiceInput('bayar');

  // 4b. Clear cart yang sudah kosong
  print('[TEST] Clear kosong:');
  await screen.onVoiceInput('kosongkan');

  // 4c. Undo saat stack kosong
  print('[TEST] Undo kosong:');
  await screen.onVoiceInput('undo');

  // ══════════════════════════════════════════════════════════════
  // TEST 5: Full Transaction (Proof of Concept)
  // ══════════════════════════════════════════════════════════════
  print('\n--- TEST 5: Full Transaction ---\n');

  await screen.onVoiceInput('jual kopi susu 2');
  await screen.onVoiceInput('tambah americano 1');
  await screen.onVoiceInput('total');
  await screen.onVoiceInput('bayar');

  // Help dan unknown
  print('\n--- Help & Unknown ---\n');
  await screen.onVoiceInput('bantuan');
  await screen.onVoiceInput('perintah aneh xyz');

  print('\n=== Demo selesai - SEMUA TEST PASSED jika error muncul di tempat yang benar ===');
}
