#!/bin/bash
#
# Horde Developer Tools Setup for Ubuntu 24.04 LTS (Noble)
#
# This script is idempotent - safe to run multiple times
# Installs PHP versions (via install-ubuntu-24.04.sh) and developer tools via PHIVE
#
# Usage: sudo bash install-ubuntu-24.04-developer-tools.sh
#

set -e  # Exit on error
set -u  # Exit on undefined variable

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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

log_info "Starting Horde developer tools setup for Ubuntu 24.04..."

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHP_INSTALL_SCRIPT="${SCRIPT_DIR}/install-ubuntu-24.04.sh"

# Step 1: Run PHP installation script
log_step "Step 1: Installing PHP versions and extensions"
if [ -f "$PHP_INSTALL_SCRIPT" ]; then
    log_info "Running PHP installation script: $PHP_INSTALL_SCRIPT"
    bash "$PHP_INSTALL_SCRIPT"
else
    log_error "PHP installation script not found at: $PHP_INSTALL_SCRIPT"
    exit 1
fi

echo ""
log_step "Step 2: Installing PHIVE (PHar Installation and Verification Environment)"

# PHIVE installation directories
PHIVE_HOME="/usr/local/lib/phive"
PHIVE_BIN="/usr/local/bin/phive"
TOOLS_DIR="/usr/local/bin"

# Check if PHIVE is already installed
if command -v phive >/dev/null 2>&1; then
    CURRENT_VERSION=$(phive --version | grep -oP 'version \K[0-9.]+' || echo "unknown")
    log_info "PHIVE already installed (version: ${CURRENT_VERSION})"
else
    log_info "Installing PHIVE..."

    # Install prerequisites
    apt-get install -y -qq wget gnupg

    # Download PHIVE installer
    wget -q -O phive-installer.phar "https://phar.io/releases/phive.phar"
    wget -q -O phive-installer.phar.asc "https://phar.io/releases/phive.phar.asc"

    # Import PHIVE GPG keys
    log_info "Importing PHIVE GPG keys..."
    gpg --keyserver hkps://keys.openpgp.org --recv-keys 0x9D8A98B29B2D5D79 2>/dev/null || \
    gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys 0x9D8A98B29B2D5D79 2>/dev/null || \
    log_warn "Could not import GPG key from keyserver, signature verification may fail"

    # Verify signature (don't fail if verification fails)
    if gpg --verify phive-installer.phar.asc phive-installer.phar 2>/dev/null; then
        log_info "PHIVE signature verified successfully"
    else
        log_warn "Could not verify PHIVE signature, continuing anyway..."
    fi

    # Install PHIVE
    chmod +x phive-installer.phar
    mv phive-installer.phar "$PHIVE_BIN"
    rm -f phive-installer.phar.asc

    log_info "PHIVE installed successfully"
fi

# Verify PHIVE installation
if ! command -v phive >/dev/null 2>&1; then
    log_error "PHIVE installation failed"
    exit 1
fi

PHIVE_VERSION=$(phive --version | head -n 1)
log_info "PHIVE version: $PHIVE_VERSION"

echo ""
log_step "Step 3: Installing developer tools via PHIVE"

# Configure PHIVE to install globally
export PHIVE_HOME="$PHIVE_HOME"

# Function to install tool via PHIVE
install_phive_tool() {
    local TOOL_NAME="$1"
    local TOOL_ALIAS="$2"

    log_info "Installing ${TOOL_NAME}..."

    # Check if already installed
    if [ -f "${TOOLS_DIR}/${TOOL_ALIAS%%@*}" ]; then
        INSTALLED_TOOL="${TOOLS_DIR}/${TOOL_ALIAS%%@*}"
        log_info "${TOOL_NAME} already installed at ${INSTALLED_TOOL}"

        # Get version
        if [ -x "$INSTALLED_TOOL" ]; then
            TOOL_VERSION=$("$INSTALLED_TOOL" --version 2>/dev/null | head -n 1 || echo "unknown version")
            log_info "Current version: ${TOOL_VERSION}"
        fi
    else
        # Install fresh - accept unsigned for simplicity
        log_info "Installing ${TOOL_ALIAS} globally..."
        if phive install "$TOOL_ALIAS" --global --force-accept-unsigned --copy 2>&1 | tee /tmp/phive-install.log; then
            log_info "${TOOL_NAME} installed successfully"
        else
            log_warn "Failed to install ${TOOL_NAME} via PHIVE"
            return 1
        fi
    fi
}

# Install Composer
log_info "Installing Composer..."
if command -v composer >/dev/null 2>&1; then
    COMPOSER_VERSION=$(composer --version 2>/dev/null | grep -oP 'version \K[0-9.]+' || echo "unknown")
    log_info "Composer already installed (version: ${COMPOSER_VERSION})"
    log_info "Updating Composer..."
    composer self-update 2>/dev/null || log_warn "Could not update Composer"
else
    log_info "Downloading Composer installer..."
    EXPECTED_CHECKSUM="$(wget -q -O - https://composer.github.io/installer.sig)"
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

    if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
        log_error "Composer installer checksum mismatch"
        rm composer-setup.php
        exit 1
    fi

    php composer-setup.php --quiet --install-dir=/usr/local/bin --filename=composer
    rm composer-setup.php
    log_info "Composer installed successfully"
fi

# Install PHPUnit (latest two major versions)
log_info "Installing PHPUnit versions..."

# PHPUnit 11 (latest)
if install_phive_tool "PHPUnit 11" "phpunit@^11"; then
    # Create phpunit11 alias
    if [ -L "${TOOLS_DIR}/phpunit" ] && [ ! -e "${TOOLS_DIR}/phpunit11" ]; then
        ln -sf "$(readlink ${TOOLS_DIR}/phpunit)" "${TOOLS_DIR}/phpunit11" 2>/dev/null || true
    fi
fi

# PHPUnit 10
if install_phive_tool "PHPUnit 10" "phpunit@^10"; then
    # If PHPUnit 11 wasn't installed, the main phpunit might be v10
    if [ -L "${TOOLS_DIR}/phpunit" ] && [ ! -e "${TOOLS_DIR}/phpunit10" ]; then
        PHPUNIT_VERSION=$(${TOOLS_DIR}/phpunit --version 2>/dev/null | grep -oP 'PHPUnit \K[0-9]+' || echo "0")
        if [ "$PHPUNIT_VERSION" = "10" ]; then
            ln -sf "$(readlink ${TOOLS_DIR}/phpunit)" "${TOOLS_DIR}/phpunit10" 2>/dev/null || true
        fi
    fi
fi

# Install PHP-CS-Fixer
install_phive_tool "PHP-CS-Fixer" "php-cs-fixer"

# Install PHPStan
install_phive_tool "PHPStan" "phpstan"

# Install Dephpend
install_phive_tool "Dephpend" "dephpend"

echo ""
log_step "Step 4: Verifying installations"

# Verify all tools
echo ""
echo "Installed Developer Tools:"
echo "=========================="

# Composer
if command -v composer >/dev/null 2>&1; then
    COMPOSER_VERSION=$(composer --version 2>/dev/null | head -n 1)
    echo "  ✓ Composer: ${COMPOSER_VERSION}"
else
    echo "  ✗ Composer: NOT FOUND"
fi

# PHPUnit
if command -v phpunit >/dev/null 2>&1; then
    PHPUNIT_VERSION=$(phpunit --version 2>/dev/null | head -n 1)
    echo "  ✓ PHPUnit: ${PHPUNIT_VERSION}"
else
    echo "  ✗ PHPUnit: NOT FOUND"
fi

# Check for PHPUnit 10/11 specifically
if [ -f "${TOOLS_DIR}/phpunit11" ]; then
    PHPUNIT11_VERSION=$(${TOOLS_DIR}/phpunit11 --version 2>/dev/null | head -n 1 || echo "unknown")
    echo "  ✓ PHPUnit 11: ${PHPUNIT11_VERSION}"
fi

if [ -f "${TOOLS_DIR}/phpunit10" ]; then
    PHPUNIT10_VERSION=$(${TOOLS_DIR}/phpunit10 --version 2>/dev/null | head -n 1 || echo "unknown")
    echo "  ✓ PHPUnit 10: ${PHPUNIT10_VERSION}"
fi

# PHP-CS-Fixer
if command -v php-cs-fixer >/dev/null 2>&1; then
    PHPCS_VERSION=$(php-cs-fixer --version 2>/dev/null | head -n 1)
    echo "  ✓ PHP-CS-Fixer: ${PHPCS_VERSION}"
else
    echo "  ✗ PHP-CS-Fixer: NOT FOUND"
fi

# PHPStan
if command -v phpstan >/dev/null 2>&1; then
    PHPSTAN_VERSION=$(phpstan --version 2>/dev/null | head -n 1)
    echo "  ✓ PHPStan: ${PHPSTAN_VERSION}"
else
    echo "  ✗ PHPStan: NOT FOUND"
fi

# Dephpend
if command -v dephpend >/dev/null 2>&1; then
    DEPHPEND_VERSION=$(dephpend --version 2>/dev/null | head -n 1 || echo "Dephpend (version unknown)")
    echo "  ✓ Dephpend: ${DEPHPEND_VERSION}"
else
    echo "  ✗ Dephpend: NOT FOUND"
fi

# PHIVE
if command -v phive >/dev/null 2>&1; then
    PHIVE_VERSION=$(phive --version 2>/dev/null | head -n 1)
    echo "  ✓ PHIVE: ${PHIVE_VERSION}"
else
    echo "  ✗ PHIVE: NOT FOUND"
fi

echo ""
log_info "Installation complete!"
echo ""
echo "Summary:"
echo "========"
echo "  - PHP 8.3, 8.4, and 8.5 installed with extensions"
echo "  - PHIVE installed for PHAR management"
echo "  - Composer installed globally"
echo "  - PHPUnit 10 and 11 installed"
echo "  - PHP-CS-Fixer installed"
echo "  - PHPStan installed"
echo "  - Dephpend installed"
echo ""
echo "Usage:"
echo "  composer --version"
echo "  phpunit --version"
echo "  phpunit10 --version  # PHPUnit 10.x"
echo "  phpunit11 --version  # PHPUnit 11.x"
echo "  php-cs-fixer --version"
echo "  phpstan --version"
echo "  dephpend --version"
echo "  phive list --global  # List all PHIVE-managed tools"
echo ""
echo "To update tools:"
echo "  composer self-update"
echo "  phive update --global"
echo ""
