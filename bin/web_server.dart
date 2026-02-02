import 'dart:convert';
import 'dart:io';

import 'package:homeai_voice/core/voice_command_coordinator.dart';
import 'package:homeai_voice/core/auth_context.dart';
import 'package:homeai_voice/intent/intent_parser.dart';
import 'package:homeai_voice/intent/intent_executor.dart';
import 'package:homeai_voice/intent/mock_intent_port.dart';

void main() async {
  // Default port 3000 untuk menghindari konflik dengan Frappe (8080)
  final port = int.tryParse(Platform.environment['PORT'] ?? '3000') ?? 3000;

  final coordinator = VoiceCommandCoordinator(
    auth: AuthContext(UserRole.barista),
    parser: IntentParser(),
    executor: IntentExecutor(MockIntentPort()),
  );

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  print('🚀 HomeAI POS Voice Server running on port $port');

  await for (final request in server) {
    try {
      await handleRequest(request, coordinator);
    } catch (e) {
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'error': e.toString()}))
        ..close();
    }
  }
}

Future<void> handleRequest(
  HttpRequest request,
  VoiceCommandCoordinator coordinator,
) async {
  // CORS headers
  request.response.headers.add('Access-Control-Allow-Origin', '*');
  request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

  if (request.method == 'OPTIONS') {
    request.response
      ..statusCode = HttpStatus.ok
      ..close();
    return;
  }

  final path = request.uri.path;

  // Health check
  if (path == '/health' && request.method == 'GET') {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'status': 'ok', 'service': 'homeai-pos-voice'}))
      ..close();
    return;
  }

  // Voice command endpoint
  if (path == '/voice' && request.method == 'POST') {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final text = data['text'] as String?;

    if (text == null || text.isEmpty) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'error': 'Missing "text" field'}))
        ..close();
      return;
    }

    print('[VOICE] Received: $text');
    await coordinator.handleVoice(text);

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'success': true, 'text': text}))
      ..close();
    return;
  }

  // 404 Not Found
  request.response
    ..statusCode = HttpStatus.notFound
    ..headers.contentType = ContentType.json
    ..write(jsonEncode({'error': 'Not found'}))
    ..close();
}
