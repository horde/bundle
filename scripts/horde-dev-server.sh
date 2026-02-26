#!/bin/bash
#
# Horde Development Server
#
# Runs PHP's built-in development server for Horde
# Default: localhost:8585 serving /srv/www/horde-dev/web
#
# Usage:
#   horde-dev-server.sh                    # localhost:8585
#   horde-dev-server.sh -p 8080            # localhost:8080
#   horde-dev-server.sh -a                 # 0.0.0.0:8585 (all interfaces)
#   horde-dev-server.sh -a -p 9000         # 0.0.0.0:9000
#   horde-dev-server.sh --php 8.4          # Use PHP 8.4
#

set -e
set -u

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Default configuration
DOCUMENT_ROOT="/srv/www/horde-dev/web"
HOST="localhost"
PORT="8585"
PHP_VERSION=""

# Parse command line arguments
show_help() {
    cat << EOF
Horde Development Server

Usage: $(basename "$0") [OPTIONS]

Options:
  -a, --all-interfaces    Listen on all interfaces (0.0.0.0) instead of localhost
  -p, --port PORT         Port number (default: 8585)
  -d, --docroot PATH      Document root directory (default: /srv/www/horde-dev/web)
  --php VERSION           PHP version to use (e.g., 8.3, 8.4, 8.5)
  -h, --help              Show this help message

Examples:
  $(basename "$0")                      # Start server on localhost:8585
  $(basename "$0") -p 8080              # Start server on localhost:8080
  $(basename "$0") -a                   # Start server on 0.0.0.0:8585
  $(basename "$0") -a -p 9000           # Start server on 0.0.0.0:9000
  $(basename "$0") --php 8.4            # Use PHP 8.4
  $(basename "$0") -a -p 8080 --php 8.5 # All options combined

EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -a|--all-interfaces)
            HOST="0.0.0.0"
            shift
            ;;
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -d|--docroot)
            DOCUMENT_ROOT="$2"
            shift 2
            ;;
        --php)
            PHP_VERSION="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
done

# Validate port number
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    log_error "Invalid port number: $PORT (must be between 1 and 65535)"
    exit 1
fi

# Check if document root exists
if [ ! -d "$DOCUMENT_ROOT" ]; then
    log_error "Document root does not exist: $DOCUMENT_ROOT"
    exit 1
fi

# Determine PHP binary to use
if [ -n "$PHP_VERSION" ]; then
    PHP_BINARY="php${PHP_VERSION}"
    if ! command -v "$PHP_BINARY" >/dev/null 2>&1; then
        log_error "PHP version $PHP_VERSION not found (tried: $PHP_BINARY)"
        log_info "Available PHP versions:"
        ls -1 /usr/bin/php[0-9]* 2>/dev/null || echo "  None found"
        exit 1
    fi
else
    PHP_BINARY="php"
fi

# Get PHP version info
PHP_VERSION_INFO=$("$PHP_BINARY" -v | head -n 1)

# Check if port is already in use
if command -v ss >/dev/null 2>&1; then
    if ss -tuln | grep -q ":${PORT} "; then
        log_error "Port $PORT is already in use"
        log_info "Active ports:"
        ss -tuln | grep LISTEN | grep ":${PORT} " || true
        exit 1
    fi
elif command -v netstat >/dev/null 2>&1; then
    if netstat -tuln | grep -q ":${PORT} "; then
        log_error "Port $PORT is already in use"
        log_info "Active ports:"
        netstat -tuln | grep LISTEN | grep ":${PORT} " || true
        exit 1
    fi
fi

# Display server information
echo ""
echo "======================================"
echo "  Horde Development Server"
echo "======================================"
echo ""
echo "  Document Root: $DOCUMENT_ROOT"
echo "  PHP Version:   $PHP_VERSION_INFO"
echo "  Listen Address: ${HOST}:${PORT}"
echo ""

if [ "$HOST" = "0.0.0.0" ]; then
    log_warn "Server is listening on ALL network interfaces"
    log_warn "This exposes Horde to your local network"
    echo ""
    log_info "Access URLs:"
    echo "    http://localhost:${PORT}/"
    # Try to get local IP addresses
    if command -v ip >/dev/null 2>&1; then
        LOCAL_IPS=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' || true)
        if [ -n "$LOCAL_IPS" ]; then
            while IFS= read -r IP; do
                echo "    http://${IP}:${PORT}/"
            done <<< "$LOCAL_IPS"
        fi
    fi
else
    log_info "Access URL: http://localhost:${PORT}/"
fi

echo ""
log_info "Starting PHP built-in server..."
log_info "Press Ctrl+C to stop"
echo ""
echo "--------------------------------------"

# Start the server
cd "$DOCUMENT_ROOT"
exec "$PHP_BINARY" -S "${HOST}:${PORT}" -t "$DOCUMENT_ROOT"
