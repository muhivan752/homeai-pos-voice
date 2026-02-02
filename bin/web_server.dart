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

  // Root - Welcome page
  if ((path == '/' || path.isEmpty) && request.method == 'GET') {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..write('''
<!DOCTYPE html>
<html>
<head>
  <title>HomeAI POS Voice</title>
  <style>
    body { font-family: system-ui; max-width: 600px; margin: 50px auto; padding: 20px; }
    h1 { color: #333; }
    code { background: #f4f4f4; padding: 2px 6px; border-radius: 4px; }
    pre { background: #f4f4f4; padding: 15px; border-radius: 8px; overflow-x: auto; }
    .endpoint { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 8px; }
    .method { display: inline-block; padding: 4px 8px; border-radius: 4px; font-weight: bold; }
    .get { background: #61affe; color: white; }
    .post { background: #49cc90; color: white; }
  </style>
</head>
<body>
  <h1>🎤 HomeAI POS Voice API</h1>
  <p>Voice command server untuk Point of Sale</p>

  <div class="endpoint">
    <span class="method get">GET</span> <code>/health</code>
    <p>Health check endpoint</p>
  </div>

  <div class="endpoint">
    <span class="method post">POST</span> <code>/voice</code>
    <p>Kirim perintah voice</p>
    <pre>{
  "text": "jual kopi susu 2"
}</pre>
  </div>

  <h3>Contoh perintah:</h3>
  <ul>
    <li><code>jual kopi susu 2</code> - Jual 2 kopi susu</li>
    <li><code>jual es teh manis 3</code> - Jual 3 es teh manis</li>
    <li><code>bayar</code> atau <code>checkout</code> - Proses pembayaran</li>
  </ul>
</body>
</html>
''')
      ..close();
    return;
  }

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
