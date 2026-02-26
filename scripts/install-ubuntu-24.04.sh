#!/bin/bash
#
# Horde Development Environment Setup for Ubuntu 24.04 LTS (Noble)
#
# This script is idempotent - safe to run multiple times
# Installs PHP 8.3, 8.4, and 8.5 with required extensions for Horde
# Sets PHP 8.3 as the default version
#
# Usage: sudo bash install-ubuntu-24.04.sh
#

set -e  # Exit on error
set -u  # Exit on undefined variable

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

log_info "Starting Horde development environment setup for Ubuntu 24.04..."

# Update package list
log_info "Updating package lists..."
apt-get update -qq

# Install prerequisites for adding PPAs
log_info "Installing prerequisites..."
apt-get install -y -qq software-properties-common apt-transport-https ca-certificates curl gnupg lsb-release

# Add ondrej/php PPA if not already added
if ! grep -q "^deb .*ondrej/php" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
    log_info "Adding ondrej/php PPA..."
    add-apt-repository -y ppa:ondrej/php
    apt-get update -qq
else
    log_info "ondrej/php PPA already configured"
fi

# Define PHP versions to install
PHP_VERSIONS=("8.3" "8.4" "8.5")
DEFAULT_PHP_VERSION="8.3"

# Core PHP extensions required by Horde
# Based on horde/base, horde/Core, horde/components composer.json requirements
# and common Horde library dependencies
CORE_EXTENSIONS=(
    "cli"           # Command-line interface
    "common"        # Common files
    "fpm"           # FastCGI Process Manager
    "bcmath"        # Arbitrary precision mathematics
    "curl"          # cURL support
    "gd"            # GD graphics library
    "intl"          # Internationalization
    "mbstring"      # Multibyte string support
    "mysql"         # MySQL/MariaDB (mysqli + pdo_mysql)
    "xml"           # XML support (dom, simplexml, xml, xmlreader, xmlwriter)
    "zip"           # ZIP archive support
    "soap"          # SOAP protocol support
    "ldap"          # LDAP support
    "imap"          # IMAP support
    "tidy"          # Tidy HTML support
    "readline"      # Readline support for CLI
    "bz2"           # Bzip2 compression
)

# Extensions that should be checked for availability before installing
CHECKED_EXTENSIONS=(
    "opcache"       # Zend OPcache (may not be available for bleeding-edge PHP)
)

# Optional but recommended extensions
OPTIONAL_EXTENSIONS=(
    "apcu"          # APCu caching
    "memcached"     # Memcached support
    "imagick"       # ImageMagick support
    "redis"         # Redis support
    "xsl"           # XSL transformations
    "pgsql"         # PostgreSQL support
)

# Install PHP versions and extensions
for VERSION in "${PHP_VERSIONS[@]}"; do
    log_info "Installing PHP ${VERSION}..."

    # Build package list for this version
    PACKAGES=()
    PACKAGES+=("php${VERSION}")

    # Add core extensions
    for EXT in "${CORE_EXTENSIONS[@]}"; do
        PACKAGES+=("php${VERSION}-${EXT}")
    done

    # Add checked extensions (don't fail if not available)
    for EXT in "${CHECKED_EXTENSIONS[@]}"; do
        if apt-cache show "php${VERSION}-${EXT}" >/dev/null 2>&1; then
            PACKAGES+=("php${VERSION}-${EXT}")
        else
            log_warn "Extension php${VERSION}-${EXT} not available, skipping"
        fi
    done

    # Add optional extensions (don't fail if not available)
    for EXT in "${OPTIONAL_EXTENSIONS[@]}"; do
        if apt-cache show "php${VERSION}-${EXT}" >/dev/null 2>&1; then
            PACKAGES+=("php${VERSION}-${EXT}")
        else
            log_warn "Optional extension php${VERSION}-${EXT} not available"
        fi
    done

    # Install all packages for this version
    log_info "Installing ${#PACKAGES[@]} packages for PHP ${VERSION}..."
    apt-get install -y -qq "${PACKAGES[@]}"

    log_info "PHP ${VERSION} installation complete"
done

# Set default PHP version using update-alternatives
log_info "Setting PHP ${DEFAULT_PHP_VERSION} as default..."

# Only set if not already the default
CURRENT_DEFAULT=$(update-alternatives --query php 2>/dev/null | grep "^Value:" | awk '{print $2}' || echo "")
DESIRED_DEFAULT="/usr/bin/php${DEFAULT_PHP_VERSION}"

if [ "$CURRENT_DEFAULT" != "$DESIRED_DEFAULT" ]; then
    update-alternatives --set php "$DESIRED_DEFAULT"
    log_info "Default PHP set to ${DEFAULT_PHP_VERSION}"
else
    log_info "PHP ${DEFAULT_PHP_VERSION} is already the default"
fi

# Verify installations
log_info "Verifying PHP installations..."
echo ""
echo "Installed PHP versions:"
echo "======================="

for VERSION in "${PHP_VERSIONS[@]}"; do
    if command -v "php${VERSION}" >/dev/null 2>&1; then
        FULL_VERSION=$("php${VERSION}" -r "echo PHP_VERSION;")
        echo "  PHP ${VERSION}: ${FULL_VERSION}"
    else
        log_error "PHP ${VERSION} not found!"
    fi
done

echo ""
DEFAULT_VERSION=$(php -r "echo PHP_VERSION;")
echo "Default PHP version: ${DEFAULT_VERSION}"
echo ""

# Display FPM status
log_info "PHP-FPM status (installed but not configured):"
for VERSION in "${PHP_VERSIONS[@]}"; do
    if systemctl list-unit-files | grep -q "php${VERSION}-fpm.service"; then
        STATUS=$(systemctl is-enabled "php${VERSION}-fpm.service" 2>/dev/null || echo "disabled")
        echo "  php${VERSION}-fpm: ${STATUS}"
    fi
done

echo ""
log_info "Installation complete!"
echo ""
echo "Summary:"
echo "========"
echo "  - PHP 8.3, 8.4, and 8.5 installed with required extensions"
echo "  - Default PHP: ${DEFAULT_PHP_VERSION}"
echo "  - PHP-FPM installed but not started/enabled"
echo "  - All core Horde extensions installed"
echo ""
echo "Usage:"
echo "  Default PHP:  php --version"
echo "  PHP 8.3:      php8.3 --version"
echo "  PHP 8.4:      php8.4 --version"
echo "  PHP 8.5:      php8.5 --version"
echo ""
echo "To start PHP-FPM for a specific version:"
echo "  systemctl start php8.3-fpm"
echo "  systemctl enable php8.3-fpm"
echo ""
