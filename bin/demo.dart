import 'dart:io';
import '../lib/core/voice_command_coordinator.dart';
import '../lib/core/auth_context.dart';
import '../lib/core/erp_client.dart';
import '../lib/intent/intent_parser.dart';
import '../lib/intent/intent_executor.dart';
import '../lib/db/local_db.dart';
import '../lib/db/local_intent_port.dart';
import '../lib/sync/sync_engine.dart';

void main() async {
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

  authService.addUser(userId: 'USR-002', username: 'barista1', password: 'barista123', role: UserRole.barista);
  authService.addUser(userId: 'USR-003', username: 'spv', password: 'spv123', role: UserRole.spv);

  final coordinator = VoiceCommandCoordinator(
    authService: authService,
    parser: IntentParser(),
    executor: IntentExecutor(localPort),
    db: db,
    syncEngine: syncEngine,
  );

  syncEngine.startAutoSync();

  print('=== HomeAI POS Voice (CLI Demo) ===\n');

  await coordinator.handleVoice('login admin admin123');
  print('');
  await coordinator.handleVoice('jual kopi susu 2');
  await coordinator.handleVoice('jual americano 1');
  await coordinator.handleVoice('bayar qris');
  print('');
  await coordinator.handleVoice('laporan hari ini');

  syncEngine.stopAutoSync();
}
