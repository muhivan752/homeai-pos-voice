#!/bin/bash
# Stop HomeAI POS Server

echo "Stopping HomeAI POS..."
pkill -f "dart.*web_server.dart" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "Server stopped"
else
    echo "Server was not running"
fi
