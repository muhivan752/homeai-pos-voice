#!/bin/bash
# HomeAI POS Startup Script

export PATH="$HOME/tools/flutter/bin:$HOME/tools/dart-sdk/bin:$PATH"
cd /home/user/homeai-pos-voice

# Kill existing process if running
pkill -f "dart.*web_server.dart" 2>/dev/null || true

# Start server
echo "Starting HomeAI POS Web Server..."
nohup dart run bin/web_server.dart 8080 > /tmp/homeai-pos.log 2>&1 &

echo "Server started on port 8080"
echo "Logs: /tmp/homeai-pos.log"
echo "PID: $!"
