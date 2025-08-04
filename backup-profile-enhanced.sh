#!/bin/bash

# Enhanced Profile Backup Script with software inventory
# Updated to use modular backup library and include modern configurations
# Version: 2.0.0

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Script configuration
readonly SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
readonly BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
readonly BACKUP_NAME="profile_backup_$BACKUP_DATE"
readonly BACKUP_ARCHIVE="$HOME/${BACKUP_NAME}.tar.gz"
readonly BACKUP_LOG="$HOME/${BACKUP_NAME}.log"
readonly BACKUP_DOC="$HOME/restore_${BACKUP_NAME}.md"
readonly SOFTWARE_LIST="$HOME/${BACKUP_NAME}_software.txt"
readonly CONFIG_FILE="$SCRIPT_DIR/backup-config.json"

# Source the backup library
if [[ -f "$SCRIPT_DIR/backup-lib.sh" ]]; then
    # shellcheck source=./backup-lib.sh
    source "$SCRIPT_DIR/backup-lib.sh"
else
    echo "ERROR: backup-lib.sh not found in $SCRIPT_DIR" >&2
    exit 1
fi

# Initialize the backup system
backup_lib_init
log_init "$BACKUP_LOG"
load_backup_config "$CONFIG_FILE"

log_message "INFO" "Starting enhanced profile backup..."
log_message "INFO" "Archive: $BACKUP_ARCHIVE"
log_message "INFO" "Using configuration: $CONFIG_FILE"

# Create comprehensive software inventory using library function
log_message "INFO" "Creating comprehensive software inventory..."
generate_software_inventory "$SOFTWARE_LIST"

# Discover backup candidates using library function
log_message "INFO" "Discovering backup candidates on system..."
BACKUP_CANDIDATES_FILE="/tmp/backup_candidates_$$"
discover_backup_candidates --include-sizes > "$BACKUP_CANDIDATES_FILE"

# Build backup lists from configuration and discovery
log_message "INFO" "Building backup lists from configuration (secure mode)..."
TEMP_SOURCES_FILE="/tmp/backup_sources_$$"

# Get secure mode items from configuration
{
    # Add dotfiles from config
    get_backup_items "secure" "dotfiles" 2>/dev/null | while IFS= read -r item; do
        if [[ -n "$item" && "$item" != "null" ]]; then
            echo "$HOME/$item"
        fi
    done
    
    # Add configurations from config
    get_backup_items "secure" "configurations" 2>/dev/null | while IFS= read -r item; do
        if [[ -n "$item" && "$item" != "null" ]]; then
            echo "$HOME/$item"
        fi
    done
    
    # Add development safe items from config
    get_backup_items "secure" "development_safe" 2>/dev/null | while IFS= read -r item; do
        if [[ -n "$item" && "$item" != "null" ]]; then
            echo "$HOME/$item"
        fi
    done
    
    # Add Claude AI items from config
    get_backup_items "secure" "claude_ai" 2>/dev/null | while IFS= read -r item; do
        if [[ -n "$item" && "$item" != "null" ]]; then
            echo "$HOME/$item"
        fi
    done
    
    # Add discovered modern configurations that exist
    while IFS=':' read -r name desc category size_or_path path_or_empty; do
        # Handle both 4 and 5 field formats from discover function
        if [[ -n "$path_or_empty" ]]; then
            # 5 field format (with sizes)
            local actual_path="$path_or_empty"
        else
            # 4 field format (without sizes)
            local actual_path="$size_or_path"
        fi
        
        # Only include if path exists and is not sensitive for secure mode
        if [[ -e "$actual_path" ]] && ! is_sensitive_path "$actual_path"; then
            echo "$actual_path"
        fi
    done < "$BACKUP_CANDIDATES_FILE"
    
} | sort -u > "$TEMP_SOURCES_FILE"

# Legacy arrays for compatibility with existing code structure
DOTFILES=()
DIRECTORIES=()

# Read sources into arrays based on type
while IFS= read -r source; do
    if [[ -f "$source" ]]; then
        # Convert absolute path to relative for dotfiles
        relative_path="${source#$HOME/}"
        DOTFILES+=("$relative_path")
    elif [[ -d "$source" ]]; then
        # Convert absolute path to relative for directories  
        relative_path="${source#$HOME/}"
        DIRECTORIES+=("$relative_path")
    fi
done < "$TEMP_SOURCES_FILE"

# Log files being backed up
log_message "INFO" "BACKING UP DOTFILES:"
for file in "${DOTFILES[@]}"; do
    if [[ -f "$HOME/$file" ]]; then
        log_message "INFO" "  [FILE] $file"
    fi
done

log_message "INFO" "BACKING UP DIRECTORIES:"
for dir in "${DIRECTORIES[@]}"; do
    # Handle glob patterns
    for path in $HOME/$dir; do
        if [[ -d "$path" ]]; then
            log_message "INFO" "  [DIR] ${path#$HOME/}"
        fi
    done
done

# Validate backup destination
if ! validate_backup_destination "$BACKUP_ARCHIVE"; then
    log_message "ERROR" "Backup destination validation failed"
    cleanup_temp_files "/tmp/backup_$$"
    exit 1
fi

# Create exclusions file for archive creation
EXCLUSIONS_FILE="/tmp/backup_exclusions_$$"
get_backup_items "secure" "exclusions" 2>/dev/null | grep -v "null" > "$EXCLUSIONS_FILE" || {
    # Fallback exclusions if config parsing fails
    cat > "$EXCLUSIONS_FILE" << 'EOF'
*.cache
*Cache*
*.log
node_modules
.local/share/Trash
.config/*/Cache
.config/*/cache
.config/chromium
.config/google-chrome
.mozilla/firefox/*/cache*
.yarn/cache
.npm/_cacache
.cargo/registry/cache
.cache
.var/app/*/cache
.git-credentials
.aws/credentials
.docker/config.json
EOF
}

# Add software inventory to backup temporarily
cp "$SOFTWARE_LIST" "$HOME/.software_inventory_backup.txt"
echo ".software_inventory_backup.txt" >> "$TEMP_SOURCES_FILE"

# Create archive using library function
log_message "INFO" "Creating backup archive..."
if create_backup_archive "$TEMP_SOURCES_FILE" "$BACKUP_ARCHIVE" "$EXCLUSIONS_FILE"; then
    ARCHIVE_SIZE=$(du -h "$BACKUP_ARCHIVE" | cut -f1)
    log_message "INFO" "Archive created successfully!"
    log_message "INFO" "Size: $ARCHIVE_SIZE"
else
    log_message "ERROR" "Failed to create backup archive"
    cleanup_temp_files "/tmp/backup_$$"
    exit 1
fi

# Clean up temporary files
rm -f "$HOME/.software_inventory_backup.txt"
cleanup_temp_files "/tmp/backup_$$"

# Calculate and verify hash using library function
log_message "INFO" "Calculating SHA256 hash..."
HASH=$(calculate_archive_hash "$BACKUP_ARCHIVE" "${BACKUP_ARCHIVE}.sha256")
if [[ $? -eq 0 ]]; then
    log_message "INFO" "SHA256: $HASH"
else
    log_message "ERROR" "Failed to calculate hash"
    exit 1
fi

# Create comprehensive restore documentation
log_message "INFO" "Creating restore documentation..."
cat > "$BACKUP_DOC" << EOF
# Profile Backup and Restore Procedures

**SHA256 Hash:** \`$HASH\`  
**Backup Date:** $(date '+%Y-%m-%d %H:%M:%S')  
**Archive File:** \`$BACKUP_NAME.tar.gz\`  
**Archive Size:** $ARCHIVE_SIZE

## Verify Backup Integrity

Before using this backup, verify its integrity:
\`\`\`bash
echo "$HASH  $BACKUP_NAME.tar.gz" | sha256sum -c
\`\`\`

## What's Included in This Backup

### Shell Configurations
- \`.bashrc\`, \`.bash_profile\`, \`.bash_logout\`, \`.profile\`
- \`.zshrc\`, \`.p10k.zsh\` (Zsh and Powerlevel10k configs)

### Development Tools
- \`.gitconfig\`, \`.git-credentials\` (Git configuration)
- \`.npmrc\`, \`.yarnrc\` (Node.js package managers)
- \`.cargo/config*\` (Rust configuration)
- \`.bun/\` (Bun runtime)
- \`.flutter\` (Flutter SDK settings)
- \`.pub-cache/\`, \`.dart-tool/\` (Dart/Flutter packages)

### Security & Authentication
- \`.ssh/\` (SSH keys and known_hosts)
- \`.gnupg/\` (GPG keys and trust database)
- \`.pki/\` (PKI certificates)
- \`.kube/\` (Kubernetes configurations)
- \`.talos/\` (Talos configurations)

### Application Configurations
- \`.config/\` (Most application settings)
- \`.local/share/\` (Application data)
- \`.local/bin/\` (User scripts and binaries)
- \`.vscode-oss/\` (VS Code OSS settings)
- \`.claude/\`, \`.claude.json\` (Claude CLI settings)

### System Configurations
- \`.nvidia-settings-rc\` (NVIDIA display settings)
- \`.fonts.conf\`, \`.fonts/\` (Font configurations)
- \`.gtkrc-2.0\` (GTK theme settings)

### Software Inventory
- \`.software_inventory_backup.txt\` (List of installed packages)

## Restore Procedure

### Step 1: Copy Backup Files
\`\`\`bash
# Copy all backup files from external storage
cp /path/to/external/drive/$BACKUP_NAME.tar.gz ~/
cp /path/to/external/drive/${BACKUP_NAME}_software.txt ~/
\`\`\`

### Step 2: Extract Backup
\`\`\`bash
cd ~
tar -xzf $BACKUP_NAME.tar.gz
\`\`\`

### Step 3: Fix Permissions
\`\`\`bash
# Critical security directories
chmod 700 ~/.ssh ~/.gnupg
chmod 600 ~/.ssh/* ~/.gnupg/*
chmod 644 ~/.ssh/*.pub ~/.ssh/known_hosts
[ -f ~/.kube/config ] && chmod 600 ~/.kube/config

# Executable permissions for user scripts
[ -d ~/.local/bin ] && chmod +x ~/.local/bin/*
\`\`\`

### Step 4: Review Software Inventory
\`\`\`bash
# View the software that was installed on the old system
less ~/.software_inventory_backup.txt
# Or open the separate detailed inventory
less ~/${BACKUP_NAME}_software.txt
\`\`\`

### Step 5: Reinstall Essential Software

Since you're switching DE/WM, not all software will be pre-installed. Here's a systematic approach:

#### Core Development Tools
\`\`\`bash
# Version control
sudo pacman -S git

# Build essentials
sudo pacman -S base-devel

# Terminal tools (if using zsh config)
sudo pacman -S zsh zsh-completions
chsh -s /usr/bin/zsh
\`\`\`

#### Language Runtimes (check your .software_inventory_backup.txt)
\`\`\`bash
# Node.js (if you had npm packages)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/latest/install.sh | bash
source ~/.bashrc
nvm install node

# Rust (if you had cargo packages)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Python pip
sudo pacman -S python-pip
\`\`\`

#### Reinstall Global Packages
\`\`\`bash
# NPM globals (from software inventory)
npm install -g <packages from inventory>

# Cargo tools
cargo install <tools from inventory>

# Python user packages
pip install --user <packages from inventory>
\`\`\`

### Step 6: Verify Configurations

Run this script to check for missing programs referenced in your configs:
\`\`\`bash
#!/bin/bash
echo "Checking for missing programs..."

# Check shell rc files
for rc in ~/.bashrc ~/.zshrc; do
    if [ -f "\$rc" ]; then
        echo "Checking \$rc..."
        # Extract potential commands (basic heuristic)
        grep -E '(alias|export PATH|command|which) ' "\$rc" | \
        grep -oE '[a-zA-Z0-9_-]+' | sort -u | \
        while read cmd; do
            if ! command -v "\$cmd" &>/dev/null 2>&1; then
                echo "  Missing: \$cmd"
            fi
        done
    fi
done

# Check .local/bin scripts
if [ -d ~/.local/bin ]; then
    echo "Checking ~/.local/bin scripts..."
    find ~/.local/bin -type f -executable | while read script; do
        # Check shebang
        interpreter=\$(head -1 "\$script" | grep '^#!' | sed 's/^#!//' | awk '{print \$1}')
        if [ -n "\$interpreter" ] && ! [ -x "\$interpreter" ]; then
            echo "  Missing interpreter for \$(basename "\$script"): \$interpreter"
        fi
    done
fi
\`\`\`

### Step 7: Application-Specific Restoration

#### VS Code/OSS
- Install VS Code OSS: \`sudo pacman -S code\`
- Extensions will need manual reinstallation
- Settings are already restored

#### Git Configuration
\`\`\`bash
# Verify git config
git config --global --list

# Test SSH access
ssh -T git@github.com
\`\`\`

## Quick Software Check Script

Save this as ~/check-restored-software.sh:
\`\`\`bash
#!/bin/bash
echo "=== Checking Restored Environment ==="

check_command() {
    if command -v \$1 &>/dev/null; then
        echo "✓ \$1 is installed"
    else
        echo "✗ \$1 is NOT installed"
    fi
}

echo -e "\\nDevelopment Tools:"
for cmd in git make gcc npm node cargo rustc python pip; do
    check_command \$cmd
done

echo -e "\\nShell & Terminal:"
for cmd in zsh tmux; do
    check_command \$cmd
done

echo -e "\\nCheck complete. Review missing items above."
\`\`\`

## Notes for DE/WM Switch

Since you're changing desktop environment/window manager:
1. GTK/Qt themes may need reconfiguration
2. Some .config entries may be DE-specific (can be ignored/removed)
3. Keyboard shortcuts will need to be reconfigured in the new DE/WM
4. System tray applications may behave differently

---
Generated: $(date '+%Y-%m-%d %H:%M:%S')
## Modern Configuration Items Included

This backup includes modern development and system configurations:

### AI/Development Tools
- Claude AI assistant configurations
- GitHub CLI and Copilot settings
- Modern editors: VS Code, Cursor, Zed, Micro, Neovim

### Wayland/Hyprland Ecosystem
- Hyprland window manager configuration
- Waybar, Rofi, Wofi, Swaylock, SwayNC configurations

### Modern Terminals & System Tools
- Ghostty, Alacritty, Kitty terminal configurations
- btop, htop, fastfetch system monitoring tools
- Starship prompt configuration

### Modern Applications
- Docker Desktop, 1Password configurations
- Brave browser settings
- Qt theming (Kvantum, qt5ct, qt6ct)
- Systemd user services
- Flatpak application data

### Container & Development
- Modern Docker and container configurations
- Updated language runtime configurations
- Modern package manager settings

EOF

# Set secure permissions on documentation
set_secure_permissions "$BACKUP_DOC" "" "600"
log_message "INFO" "Documentation created: $BACKUP_DOC"

# Final summary using library logging
echo ""
echo -e "${GREEN}Enhanced Backup Complete!${NC}"
echo "========================"
echo "Archive: $BACKUP_ARCHIVE"
echo "Size: $ARCHIVE_SIZE"
echo "SHA256: $HASH"
echo "Hash File: ${BACKUP_ARCHIVE}.sha256"
echo "Log: $BACKUP_LOG"
echo "Docs: $BACKUP_DOC"
echo "Software: $SOFTWARE_LIST"
echo ""
echo "Modern configurations included:"
echo "• AI tools (Claude, GitHub Copilot)"
echo "• Modern editors (Code, Cursor, Zed, Neovim)"
echo "• Wayland/Hyprland ecosystem"
echo "• Modern terminals and system tools"
echo "• Container and development tools"
echo "• Flatpak application data"
echo ""
echo "Next steps:"
echo "1. Verify: echo \"$HASH  $BACKUP_NAME.tar.gz\" | sha256sum -c"
echo "2. Copy all files to external storage before reinstalling"
echo "3. Review $SOFTWARE_LIST to prepare for software reinstallation"
echo ""
log_message "INFO" "Enhanced backup completed successfully"