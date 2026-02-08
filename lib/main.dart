import 'dart:io';
import 'core/voice_command_coordinator.dart';
import 'core/auth_context.dart';
import 'core/erp_client.dart';
import 'intent/intent_parser.dart';
import 'intent/intent_executor.dart';
import 'db/local_db.dart';
import 'db/local_intent_port.dart';
import 'sync/sync_engine.dart';

void main() async {
  // --- Inisialisasi ---
  final db = LocalDB();
  await db.init();

  final erp = ERPClient(
    baseUrl: Platform.environment['ERP_BASE_URL'] ?? 'http://localhost:8080',
    apiKey: Platform.environment['ERP_API_KEY'] ?? '',
    apiSecret: Platform.environment['ERP_API_SECRET'] ?? '',
  );

  final localPort = LocalIntentPort(db);
  final syncEngine = SyncEngine(db: db, erp: erp);
  final authService = AuthService();

  // Default users
  authService.addUser(
    userId: 'USR-002',
    username: 'barista1',
    password: 'barista123',
    role: UserRole.barista,
  );
  authService.addUser(
    userId: 'USR-003',
    username: 'spv',
    password: 'spv123',
    role: UserRole.spv,
  );

  final coordinator = VoiceCommandCoordinator(
    authService: authService,
    parser: IntentParser(),
    executor: IntentExecutor(localPort),
    db: db,
    syncEngine: syncEngine,
  );

  // Start auto-sync
  syncEngine.startAutoSync();

  // --- Demo: Simulasi voice commands ---
  print('=== HomeAI POS Voice ===\n');

  // Login
  await coordinator.handleVoice('login admin admin123');
  print('');

  // Jual beberapa item
  await coordinator.handleVoice('jual kopi susu 2');
  await coordinator.handleVoice('jual americano 1');
  await coordinator.handleVoice('jual matcha latte 3');
  print('');

  // Batal 1 item
  await coordinator.handleVoice('batal americano');
  print('');

  // Cek stok
  await coordinator.handleVoice('cek stok');
  print('');

  // Checkout
  await coordinator.handleVoice('bayar qris');
  print('');

  // Laporan
  await coordinator.handleVoice('laporan hari ini');
  print('');

  // Sync status
  final status = syncEngine.getStatus();
  print('[INFO] Sync status: $status');

  syncEngine.stopAutoSync();
}
