#!/bin/bash

# Backup UI Installation Script
# Installs the backup-ui binary and configuration file to appropriate locations

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}==== Backup UI Installation ====${NC}"

# Check if running as root (for system-wide installation)
if [ "$EUID" -eq 0 ]; then
    echo "Installing system-wide..."
    INSTALL_MODE="system"
    BIN_DIR="/usr/local/bin"
    CONFIG_DIR="/etc/backup-manager"
else
    echo "Installing for current user..."
    INSTALL_MODE="user"
    BIN_DIR="$HOME/.local/bin"
    CONFIG_DIR="$HOME/.config/backup-manager"
fi

# Check if cargo is available for building
if ! command -v cargo &> /dev/null; then
    echo -e "${RED}Error: cargo not found. Please install Rust first.${NC}"
    exit 1
fi

# Build the project
echo -e "${YELLOW}Building backup-ui...${NC}"
cargo build --release

# Check if build was successful
if [ ! -f "target/release/backup-ui" ]; then
    echo -e "${RED}Error: Build failed. Binary not found.${NC}"
    exit 1
fi

# Create necessary directories
echo "Creating directories..."
mkdir -p "$BIN_DIR"
mkdir -p "$CONFIG_DIR"

# Install the binary
echo "Installing binary to $BIN_DIR..."
cp target/release/backup-ui "$BIN_DIR/"
chmod +x "$BIN_DIR/backup-ui"

# Install the configuration file
echo "Installing configuration to $CONFIG_DIR..."
if [ -f "backup-config.json" ]; then
    cp backup-config.json "$CONFIG_DIR/"
    echo -e "${GREEN}Configuration file installed to: $CONFIG_DIR/backup-config.json${NC}"
else
    echo -e "${YELLOW}Warning: backup-config.json not found in current directory${NC}"
    echo "You'll need to create it manually or copy it from the project directory"
fi

# Add bin directory to PATH if needed (for user installation)
if [ "$INSTALL_MODE" = "user" ]; then
    # Check if bin directory is in PATH
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        echo -e "${YELLOW}Note: $BIN_DIR is not in your PATH${NC}"
        echo "Add the following to your ~/.bashrc or ~/.zshrc:"
        echo "  export PATH=\"\$PATH:$BIN_DIR\""
    fi
fi

echo -e "${GREEN}==== Installation Complete ====${NC}"
echo ""
echo "You can now run 'backup-ui' from anywhere"
echo "Configuration file location: $CONFIG_DIR/backup-config.json"
echo ""

# Test if backup-ui is accessible
if command -v backup-ui &> /dev/null; then
    echo -e "${GREEN}✓ backup-ui is in your PATH and ready to use${NC}"
else
    echo -e "${YELLOW}! backup-ui is installed but not yet in PATH${NC}"
    echo "  Either restart your shell or run: export PATH=\"\$PATH:$BIN_DIR\""
fi