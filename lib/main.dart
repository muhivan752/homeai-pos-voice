import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app/pos_app.dart';
import 'app/providers/cart_provider.dart';
import 'app/providers/voice_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => VoiceProvider()),
      ],
      child: const PosApp(),
    ),
  );
}
