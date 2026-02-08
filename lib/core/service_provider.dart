import 'auth_context.dart';
import 'erp_client.dart';
import 'voice_command_coordinator.dart';
import '../intent/intent_parser.dart';
import '../intent/intent_executor.dart';
import '../db/local_db.dart';
import '../db/local_intent_port.dart';
import '../sync/sync_engine.dart';

class ServiceProvider {
  static final ServiceProvider _instance = ServiceProvider._();
  factory ServiceProvider() => _instance;
  ServiceProvider._();

  late final AuthService authService;
  late final LocalDB db;
  late final ERPClient erp;
  late final SyncEngine syncEngine;
  late final VoiceCommandCoordinator coordinator;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    db = LocalDB();
    await db.init();

    erp = ERPClient(
      baseUrl: const String.fromEnvironment('ERP_BASE_URL', defaultValue: 'http://localhost:8080'),
      apiKey: const String.fromEnvironment('ERP_API_KEY', defaultValue: ''),
      apiSecret: const String.fromEnvironment('ERP_API_SECRET', defaultValue: ''),
    );

    final localPort = LocalIntentPort(db);
    syncEngine = SyncEngine(db: db, erp: erp);
    authService = AuthService();

    // Default users
    authService.addUser(userId: 'USR-002', username: 'barista1', password: 'barista123', role: UserRole.barista);
    authService.addUser(userId: 'USR-003', username: 'spv', password: 'spv123', role: UserRole.spv);

    coordinator = VoiceCommandCoordinator(
      authService: authService,
      parser: IntentParser(),
      executor: IntentExecutor(localPort),
      db: db,
      syncEngine: syncEngine,
    );

    syncEngine.startAutoSync();
    _initialized = true;
  }

  Future<void> resetDatabase() async {
    db.clearCart();
    await db.init();
  }
}
