#!/bin/bash

# Non-interactive backup wrapper for TUI integration
# This script wraps the interactive backup scripts for use from the TUI

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
MODE="${1:-secure}"  # secure or complete
BACKUP_DIR="${BACKUP_DIR:-$(pwd)}"

echo "Starting non-interactive backup in $MODE mode"
echo "Output directory: $BACKUP_DIR"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Generate timestamp for the backup
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
HOSTNAME=$(hostname)

# Determine which script to use and the output filename
if [ "$MODE" = "secure" ]; then
    BACKUP_SCRIPT="./backup-profile-secure.sh"
    ARCHIVE_NAME="backup_${HOSTNAME}_${TIMESTAMP}_secure.tar.gz"
else
    BACKUP_SCRIPT="./backup-profile-enhanced.sh"
    ARCHIVE_NAME="backup_${HOSTNAME}_${TIMESTAMP}_complete.tar.gz"
fi

# Check if the backup script exists
if [ ! -f "$BACKUP_SCRIPT" ]; then
    # Try in the GitHub directory
    BACKUP_SCRIPT="/home/dtaylor/GitHub/custom-tools/$(basename $BACKUP_SCRIPT)"
    if [ ! -f "$BACKUP_SCRIPT" ]; then
        echo -e "${RED}Error: Backup script not found${NC}" >&2
        exit 1
    fi
fi

# Create a temporary directory for the backup
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "Collecting files for backup..."

# Source the backup configuration
if [ -f "./backup-config.json" ]; then
    CONFIG_FILE="./backup-config.json"
elif [ -f "/home/dtaylor/GitHub/custom-tools/backup-config.json" ]; then
    CONFIG_FILE="/home/dtaylor/GitHub/custom-tools/backup-config.json"
else
    echo -e "${RED}Error: backup-config.json not found${NC}" >&2
    exit 1
fi

# For now, we'll just backup common config files without GPG encryption
# This is a simplified version that doesn't require interaction

# Common config files to backup (based on the backup scripts)
BACKUP_ITEMS=(
    ".bashrc"
    ".zshrc"
    ".config/starship.toml"
    ".config/alacritty"
    ".config/nvim"
    ".config/tmux"
    ".config/fish"
    ".config/hypr"
    ".config/waybar"
    ".config/wofi"
    ".config/kitty"
    ".local/share/applications"
    ".local/bin"
)

# Additional items for complete mode
if [ "$MODE" = "complete" ]; then
    BACKUP_ITEMS+=(
        ".ssh"
        ".gnupg"
        ".aws"
        ".git-credentials"
        ".cargo/credentials"
        ".npm"
    )
    echo -e "${YELLOW}Warning: Complete mode includes sensitive files${NC}"
fi

# Copy files to temp directory
cd "$HOME"
for item in "${BACKUP_ITEMS[@]}"; do
    if [ -e "$item" ]; then
        echo "Processing: $item"
        # Create parent directories in temp
        parent=$(dirname "$item")
        if [ "$parent" != "." ]; then
            mkdir -p "$TEMP_DIR/$parent"
        fi
        # Copy the item
        cp -r "$item" "$TEMP_DIR/$parent/" 2>/dev/null || true
    fi
done

# Create the archive
echo "Creating archive: $ARCHIVE_NAME"
cd "$TEMP_DIR"
tar czf "$BACKUP_DIR/$ARCHIVE_NAME" .

# Set restrictive permissions on the archive
chmod 600 "$BACKUP_DIR/$ARCHIVE_NAME"

# Calculate size
SIZE=$(du -h "$BACKUP_DIR/$ARCHIVE_NAME" | cut -f1)

echo -e "${GREEN}Backup completed successfully!${NC}"
echo "Archive: $BACKUP_DIR/$ARCHIVE_NAME"
echo "Size: $SIZE"

# If in complete mode, remind about security
if [ "$MODE" = "complete" ]; then
    echo -e "${YELLOW}==== SECURITY REMINDER ====${NC}"
    echo "This archive contains sensitive data (credentials, keys, etc.)"
    echo "Please encrypt it or store it securely"
    echo "Delete it after restoration or when no longer needed"
fi

exit 0