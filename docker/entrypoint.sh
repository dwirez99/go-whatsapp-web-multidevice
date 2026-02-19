#!/bin/sh
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}[STARTUP] WhatsApp Go Multi-Device Service${NC}"
echo -e "${GREEN}[STARTUP] Version: v8.3.0${NC}"
echo ""

# Ensure all required directories exist
echo -e "${YELLOW}[STARTUP] Creating required directories...${NC}"
mkdir -p /app/storages
mkdir -p /app/statics/qrcode
mkdir -p /app/statics/senditems
mkdir -p /app/statics/media
chmod 777 /app/storages /app/statics /app/statics/qrcode /app/statics/senditems /app/statics/media

echo -e "${GREEN}[STARTUP] Directory structure created:${NC}"
ls -la /app/

echo ""
echo -e "${YELLOW}[STARTUP] Environment Variables:${NC}"
echo "APP_PORT: ${APP_PORT:-3000}"
echo "APP_HOST: ${APP_HOST:-0.0.0.0}"
echo "APP_DEBUG: ${APP_DEBUG:-false}"
echo "DATABASE_URL: ${DATABASE_URL:-file:storages/whatsapp.db}"

echo ""
echo -e "${YELLOW}[STARTUP] Checking app binary...${NC}"
if [ -f /app/whatsapp ]; then
    echo -e "${GREEN}[STARTUP] ✓ Binary found: /app/whatsapp${NC}"
    ls -lh /app/whatsapp
else
    echo -e "${RED}[STARTUP] ✗ Binary NOT found: /app/whatsapp${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}[STARTUP] Starting application with command: rest${NC}"
echo -e "${GREEN}[STARTUP] =====================================${NC}"
echo ""

# Run the application
exec /app/whatsapp rest "$@"
