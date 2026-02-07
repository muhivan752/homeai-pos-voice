import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app/pos_app.dart';
import 'app/providers/cart_provider.dart';
import 'app/providers/voice_provider.dart';
import 'app/providers/product_provider.dart';
import 'app/services/sync_service.dart';
import 'app/services/erp_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  final erpService = ErpService();
  final syncService = SyncService();

  await erpService.init();
  await syncService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => VoiceProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()..loadProducts()),
        ChangeNotifierProvider.value(value: syncService),
      ],
      child: const PosApp(),
    ),
  );
}
