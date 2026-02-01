import 'dart:io';

/// Simple HTTP server to serve Flutter web build.
///
/// Usage: dart run bin/web_server.dart [port]
/// Default port: 8080
void main(List<String> args) async {
  final port = args.isNotEmpty ? int.tryParse(args[0]) ?? 8080 : 8080;
  final webDir = Directory('build/web');

  print('HomeAI POS Web Server starting...');
  print('Working directory: ${Directory.current.path}');
  print('Port: $port');

  if (!await webDir.exists()) {
    print('ERROR: build/web not found. Run "flutter build web" first.');
    print('Expected path: ${webDir.absolute.path}');
    exit(1);
  }

  print('Web directory found: ${webDir.absolute.path}');

  try {
    final server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      port,
    );

    print('HomeAI POS Web Server');
    print('Serving on http://0.0.0.0:$port');
    print('Press Ctrl+C to stop');

    await for (final request in server) {
      try {
        await _handleRequest(request, webDir.path);
      } catch (e, stack) {
        print('Error handling request: $e');
        print(stack);
      }
    }
  } on SocketException catch (e) {
    print('ERROR: Cannot bind to port $port');
    print('Reason: ${e.message}');
    print('');
    print('Possible solutions:');
    print('  1. Check if port $port is already in use: sudo lsof -i :$port');
    print('  2. Kill the process using the port');
    print('  3. Use a different port');
    exit(2);
  } catch (e, stack) {
    print('ERROR: Failed to start server');
    print('Exception: $e');
    print(stack);
    exit(3);
  }
}

Future<void> _handleRequest(HttpRequest request, String webRoot) async {
  var path = request.uri.path;

  // Default to index.html
  if (path == '/') {
    path = '/index.html';
  }

  final filePath = '$webRoot$path';
  final file = File(filePath);

  if (await file.exists()) {
    // Set content type
    final contentType = _getContentType(path);
    request.response.headers.contentType = contentType;

    // Add CORS headers for development
    request.response.headers.add('Access-Control-Allow-Origin', '*');

    // Serve file
    await request.response.addStream(file.openRead());
  } else {
    // Serve index.html for SPA routing (Flutter web uses hash routing by default)
    final indexFile = File('$webRoot/index.html');
    if (await indexFile.exists()) {
      request.response.headers.contentType = ContentType.html;
      await request.response.addStream(indexFile.openRead());
    } else {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('Not Found');
    }
  }

  await request.response.close();

  // Log request
  print('${request.method} ${request.uri.path} -> ${request.response.statusCode}');
}

ContentType _getContentType(String path) {
  final ext = path.split('.').last.toLowerCase();

  switch (ext) {
    case 'html':
      return ContentType.html;
    case 'css':
      return ContentType('text', 'css', charset: 'utf-8');
    case 'js':
      return ContentType('application', 'javascript', charset: 'utf-8');
    case 'json':
      return ContentType.json;
    case 'png':
      return ContentType('image', 'png');
    case 'jpg':
    case 'jpeg':
      return ContentType('image', 'jpeg');
    case 'svg':
      return ContentType('image', 'svg+xml');
    case 'ico':
      return ContentType('image', 'x-icon');
    case 'woff':
      return ContentType('font', 'woff');
    case 'woff2':
      return ContentType('font', 'woff2');
    case 'ttf':
      return ContentType('font', 'ttf');
    case 'otf':
      return ContentType('font', 'otf');
    default:
      return ContentType.binary;
  }
}
