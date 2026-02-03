#!/bin/bash
#
# HomeAI POS Voice - Installer Script
# Jalankan di VPS: sudo bash install.sh
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}"
echo "╔════════════════════════════════════════╗"
echo "║     HomeAI POS Voice Installer         ║"
echo "║     Phase 2: Tablet UI                 ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"

# Check root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root: sudo bash install.sh${NC}"
  exit 1
fi

APP_DIR="/opt/homeai-pos-voice"
DART_DIR="/opt/dart-sdk"
FLUTTER_DIR="/opt/flutter"
SERVICE_USER="ivan_botak"  # Ganti sesuai user kamu
WEB_PORT="${1:-8080}"      # Port default 8080, bisa diubah via: sudo bash install.sh 8088

# ============================================
# 1. Install Dependencies
# ============================================
echo -e "${YELLOW}[1/7] Installing dependencies...${NC}"
apt-get update -qq
apt-get install -y -qq unzip curl git xz-utils

# ============================================
# 2. Fix Git Repository
# ============================================
echo -e "${YELLOW}[2/7] Setting up repository...${NC}"
cd $APP_DIR

# Stash local changes and pull
git config --global --add safe.directory $APP_DIR
git stash 2>/dev/null || true
git fetch origin
git checkout claude/refactor-clean-architecture-aBT17
git reset --hard origin/claude/refactor-clean-architecture-aBT17

echo -e "${GREEN}   Repository updated${NC}"

# ============================================
# 3. Install Dart SDK
# ============================================
echo -e "${YELLOW}[3/7] Installing Dart SDK...${NC}"
if [ ! -d "$DART_DIR" ]; then
  cd /tmp
  curl -fsSL https://storage.googleapis.com/dart-archive/channels/stable/release/latest/sdk/dartsdk-linux-x64-release.zip -o dart-sdk.zip
  unzip -q -o dart-sdk.zip
  mv dart-sdk $DART_DIR
  rm dart-sdk.zip
  echo -e "${GREEN}   Dart SDK installed${NC}"
else
  echo -e "${GREEN}   Dart SDK already installed${NC}"
fi

# Add to PATH
export PATH="$DART_DIR/bin:$PATH"

# ============================================
# 4. Install Flutter SDK
# ============================================
echo -e "${YELLOW}[4/7] Installing Flutter SDK...${NC}"
if [ ! -d "$FLUTTER_DIR" ]; then
  cd /tmp
  curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.27.1-stable.tar.xz -o flutter.tar.xz
  tar -xf flutter.tar.xz
  mv flutter $FLUTTER_DIR
  rm flutter.tar.xz
  echo -e "${GREEN}   Flutter SDK installed${NC}"
else
  echo -e "${GREEN}   Flutter SDK already installed${NC}"
fi

# Add to PATH and fix git ownership
export PATH="$FLUTTER_DIR/bin:$PATH"
git config --global --add safe.directory $FLUTTER_DIR

# ============================================
# 5. Build Flutter Web
# ============================================
echo -e "${YELLOW}[5/7] Building Flutter web app...${NC}"
cd $APP_DIR

flutter config --enable-web
flutter pub get
flutter build web --release

echo -e "${GREEN}   Build complete${NC}"

# ============================================
# 6. Setup Systemd Service
# ============================================
echo -e "${YELLOW}[6/7] Setting up systemd service (port: $WEB_PORT)...${NC}"

# Stop existing service first
systemctl stop homeai-pos 2>/dev/null || true

# Check if port is in use (excluding our own service)
check_port_in_use() {
  local port=$1
  if lsof -i :$port >/dev/null 2>&1; then
    local proc_name=$(lsof -i :$port -t 2>/dev/null | head -1 | xargs -I {} ps -p {} -o comm= 2>/dev/null)
    echo -e "${YELLOW}   Port $port sedang dipakai oleh: $proc_name${NC}"
    return 0
  fi
  return 1
}

# Kill any process using the port (with confirmation for non-dart processes)
if check_port_in_use $WEB_PORT; then
  echo -e "${YELLOW}   Menghentikan proses di port $WEB_PORT...${NC}"
  fuser -k $WEB_PORT/tcp 2>/dev/null || true
  sleep 2

  # Double check
  if check_port_in_use $WEB_PORT; then
    echo -e "${RED}   GAGAL membebaskan port $WEB_PORT!${NC}"
    echo -e "${YELLOW}   Gunakan port lain: sudo bash install.sh 8088${NC}"
    exit 1
  fi
fi

echo -e "${GREEN}   Port $WEB_PORT tersedia${NC}"

cat > /etc/systemd/system/homeai-pos.service << EOF
[Unit]
Description=HomeAI POS Voice Web Server
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$APP_DIR
Environment="PATH=$FLUTTER_DIR/bin:$DART_DIR/bin:/usr/local/bin:/usr/bin:/bin"
Environment="PORT=$WEB_PORT"
ExecStart=$DART_DIR/bin/dart run bin/web_server.dart $WEB_PORT
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Set ownership
chown -R $SERVICE_USER:$SERVICE_USER $APP_DIR

systemctl daemon-reload
systemctl enable homeai-pos
systemctl start homeai-pos

# Wait and check status
sleep 3
if systemctl is-active --quiet homeai-pos; then
  echo -e "${GREEN}   Systemd service configured and running${NC}"
else
  echo -e "${RED}   Service failed to start! Checking logs...${NC}"
  journalctl -u homeai-pos -n 20 --no-pager
fi

# ============================================
# 7. Setup Firewall (optional)
# ============================================
echo -e "${YELLOW}[7/7] Configuring firewall...${NC}"
if command -v ufw &> /dev/null; then
  ufw allow $WEB_PORT/tcp 2>/dev/null || true
  echo -e "${GREEN}   Port $WEB_PORT opened${NC}"
else
  echo -e "${YELLOW}   UFW not installed, skip firewall config${NC}"
fi

# ============================================
# Done!
# ============================================
echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗"
echo "║         Installation Complete!         ║"
echo "╚════════════════════════════════════════╝${NC}"
echo ""

# Get public IP
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

echo -e "Access POS dari tablet:"
echo -e "${GREEN}   http://$PUBLIC_IP:$WEB_PORT${NC}"
echo ""
echo -e "Commands:"
echo -e "   ${YELLOW}sudo systemctl status homeai-pos${NC}  - Cek status"
echo -e "   ${YELLOW}sudo systemctl restart homeai-pos${NC} - Restart"
echo -e "   ${YELLOW}sudo journalctl -u homeai-pos -f${NC}  - Lihat logs"
echo ""
