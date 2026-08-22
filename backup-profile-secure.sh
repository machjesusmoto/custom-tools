#!/bin/bash

# Secure Profile Backup Script with encryption and security warnings
# Updated to use modular backup library with enhanced security features
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

# Enhanced security warning with detailed information
echo -e "${RED}==== COMPREHENSIVE SECURITY WARNING ====${NC}"
echo "This script will backup sensitive data including:"
echo ""
echo -e "${YELLOW}HIGH-RISK ITEMS:${NC}"
echo "  • SSH private keys (~/.ssh/) - Full server access"
echo "  • GPG private keys (~/.gnupg/) - Identity and encryption"
echo "  • Kubernetes configs (~/.kube/) - Cluster access credentials"
echo "  • Cloud credentials (~/.aws/, ~/.docker/) - Account access"
echo "  • Application tokens (GitHub, etc.) - Service authentication"
echo ""
echo -e "${YELLOW}MEDIUM-RISK ITEMS:${NC}"
echo "  • Git credentials (if stored) - Repository access"
echo "  • Browser profiles - Saved passwords and sessions"
echo "  • Application data - Personal information"
echo ""
echo -e "${RED}CRITICAL SECURITY NOTICE:${NC}"
echo "Without encryption, this backup exposes ALL your credentials!"
echo "Anyone with access to the backup file can:"
echo "  • Access all your servers and services"
echo "  • Impersonate you digitally"
echo "  • Access your cloud resources"
echo ""

# Get backup mode choice
echo "Backup mode options:"
echo "1. SECURE mode - Excludes high-risk credentials (recommended for most users)"
echo "2. COMPLETE mode - Includes ALL data including credentials (requires encryption)"
echo ""
read -p "Select backup mode (1=secure, 2=complete): " -r MODE_CHOICE

case "$MODE_CHOICE" in
    1)
        BACKUP_MODE="secure"
        INCLUDE_CREDENTIALS=false
        echo -e "${GREEN}Selected: SECURE mode (credentials excluded)${NC}"
        ;;
    2)
        BACKUP_MODE="complete"
        INCLUDE_CREDENTIALS=true
        echo -e "${YELLOW}Selected: COMPLETE mode (credentials included)${NC}"
        echo ""
        echo -e "${RED}WARNING: You MUST encrypt this backup!${NC}"
        ;;
    *)
        echo "Invalid choice. Defaulting to SECURE mode."
        BACKUP_MODE="secure"
        INCLUDE_CREDENTIALS=false
        ;;
esac

echo ""
read -p "Do you want to continue with $BACKUP_MODE mode? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Backup cancelled."
    exit 0
fi

# Encryption decision
echo ""
ENCRYPT_BACKUP=false
if [[ "$INCLUDE_CREDENTIALS" == "true" ]]; then
    echo -e "${RED}ENCRYPTION IS MANDATORY for complete mode${NC}"
    ENCRYPT_BACKUP=true
else
    read -p "Would you like to encrypt the backup with GPG? (recommended) (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ENCRYPT_BACKUP=true
    fi
fi

log_message "INFO" "Starting secure profile backup..."
log_message "INFO" "Archive: $BACKUP_ARCHIVE"
log_message "INFO" "Mode: $BACKUP_MODE"
log_message "INFO" "Encryption: $ENCRYPT_BACKUP"
log_message "INFO" "Using configuration: $CONFIG_FILE"

# Create comprehensive software inventory using library function
log_message "INFO" "Creating comprehensive software inventory..."
generate_software_inventory "$SOFTWARE_LIST"

# Discover backup candidates using library function
log_message "INFO" "Discovering backup candidates on system..."
BACKUP_CANDIDATES_FILE="/tmp/backup_candidates_$$"
discover_backup_candidates --include-sizes > "$BACKUP_CANDIDATES_FILE"

# Build backup lists from configuration based on selected mode
log_message "INFO" "Building backup lists from configuration ($BACKUP_MODE mode)..."
TEMP_SOURCES_FILE="/tmp/backup_sources_$$"

# Get items based on backup mode from configuration
{
    # Add dotfiles from config
    get_backup_items "$BACKUP_MODE" "dotfiles" 2>/dev/null | while IFS= read -r item; do
        if [[ -n "$item" && "$item" != "null" ]]; then
            echo "$HOME/$item"
        fi
    done
    
    # Add configurations from config
    get_backup_items "$BACKUP_MODE" "configurations" 2>/dev/null | while IFS= read -r item; do
        if [[ -n "$item" && "$item" != "null" ]]; then
            echo "$HOME/$item"
        fi
    done
    
    # Add development items from config
    if [[ "$BACKUP_MODE" == "complete" ]]; then
        get_backup_items "$BACKUP_MODE" "development_complete" 2>/dev/null | while IFS= read -r item; do
            if [[ -n "$item" && "$item" != "null" ]]; then
                echo "$HOME/$item"
            fi
        done
        
        # Add credentials for complete mode
        get_backup_items "$BACKUP_MODE" "credentials" 2>/dev/null | while IFS= read -r item; do
            if [[ -n "$item" && "$item" != "null" ]]; then
                echo "$HOME/$item"
            fi
        done
    else
        get_backup_items "$BACKUP_MODE" "development_safe" 2>/dev/null | while IFS= read -r item; do
            if [[ -n "$item" && "$item" != "null" ]]; then
                echo "$HOME/$item"
            fi
        done
    fi
    
    # Add Claude AI items from config
    get_backup_items "$BACKUP_MODE" "claude_ai" 2>/dev/null | while IFS= read -r item; do
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
        
        # Include based on backup mode and sensitivity
        if [[ -e "$actual_path" ]]; then
            if [[ "$BACKUP_MODE" == "complete" ]]; then
                # Include everything in complete mode
                echo "$actual_path"
            else
                # Only include non-sensitive items in secure mode
                if ! is_sensitive_path "$actual_path"; then
                    echo "$actual_path"
                fi
            fi
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

# Enhanced security analysis and warnings
log_message "INFO" "Performing security analysis of backup contents..."

# Check for sensitive files in the backup selection
SENSITIVE_FILES_FOUND=false
while IFS= read -r source; do
    if is_sensitive_path "$source"; then
        if [[ "$BACKUP_MODE" == "complete" ]]; then
            log_message "WARN" "SENSITIVE: Including $source (complete mode)"
        else
            log_message "ERROR" "UNEXPECTED: Sensitive file in secure mode: $source"
        fi
        SENSITIVE_FILES_FOUND=true
    fi
done < "$TEMP_SOURCES_FILE"

# Mode-specific security warnings
if [[ "$BACKUP_MODE" == "secure" ]]; then
    log_message "INFO" "SECURITY: Using secure mode - sensitive credentials excluded"
    
    # Check for sensitive files that should be backed up separately if needed
    local sensitive_candidates=(
        ".git-credentials" ".aws/credentials" ".docker/config.json"
        ".npmrc" ".pypirc" ".netrc" ".config/gh/hosts.yml"
    )
    
    for sensitive_file in "${sensitive_candidates[@]}"; do
        if [[ -f "$HOME/$sensitive_file" ]]; then
            log_message "WARN" "EXCLUDED: $sensitive_file (contains credentials - backup separately if needed)"
        fi
    done
else
    log_message "WARN" "SECURITY: Using complete mode - ALL credentials included!"
    if [[ "$ENCRYPT_BACKUP" != "true" ]]; then
        log_message "ERROR" "CRITICAL: Complete mode without encryption is dangerous!"
        exit 1
    fi
fi

# Log files being backed up with enhanced security context
log_message "INFO" "BACKING UP DOTFILES:"
for file in "${DOTFILES[@]}"; do
    if [[ -f "$HOME/$file" ]]; then
        if is_sensitive_path "$file"; then
            log_message "WARN" "  [FILE] $file (SENSITIVE)"
        else
            log_message "INFO" "  [FILE] $file"
        fi
    fi
done

log_message "INFO" "BACKING UP DIRECTORIES:"
for dir in "${DIRECTORIES[@]}"; do
    # Handle glob patterns
    for path in $HOME/$dir; do
        if [[ -d "$path" ]]; then
            local dir_name="${path#$HOME/}"
            if is_sensitive_path "$path"; then
                log_message "WARN" "  [DIR] $dir_name (SENSITIVE)"
                # Provide specific warnings for known sensitive directories
                case "$path" in
                    */.ssh)
                        log_message "WARN" "    • Contains SSH private keys - full server access"
                        ;;
                    */.gnupg)
                        log_message "WARN" "    • Contains GPG private keys - identity and encryption"
                        ;;
                    */.kube)
                        log_message "WARN" "    • Contains cluster credentials - Kubernetes access"
                        ;;
                    */.aws)
                        log_message "WARN" "    • Contains AWS credentials - cloud account access"
                        ;;
                    */.docker)
                        log_message "WARN" "    • May contain registry credentials"
                        ;;
                    */1Password)
                        log_message "WARN" "    • Contains password manager data"
                        ;;
                    */Termius)
                        log_message "WARN" "    • Contains SSH connection data"
                        ;;
                esac
            else
                log_message "INFO" "  [DIR] $dir_name"
            fi
        fi
    done
done

# Validate backup destination with enhanced security
if ! validate_backup_destination "$BACKUP_ARCHIVE"; then
    log_message "ERROR" "Backup destination validation failed"
    cleanup_temp_files "/tmp/backup_$$"
    exit 1
fi

# Create exclusions file based on backup mode
EXCLUSIONS_FILE="/tmp/backup_exclusions_$$"
get_backup_items "$BACKUP_MODE" "exclusions" 2>/dev/null | grep -v "null" > "$EXCLUSIONS_FILE" || {
    # Fallback exclusions based on mode
    if [[ "$BACKUP_MODE" == "secure" ]]; then
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
    else
        # Complete mode - fewer exclusions
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
EOF
    fi
}

# Add software inventory to backup temporarily
cp "$SOFTWARE_LIST" "$HOME/.software_inventory_backup.txt"
echo ".software_inventory_backup.txt" >> "$TEMP_SOURCES_FILE"

# Create archive using library function with enhanced security
log_message "INFO" "Creating secure backup archive..."
# Set umask for secure file creation
umask 077

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

# Calculate and verify hash using library function
log_message "INFO" "Calculating SHA256 hash..."
HASH=$(calculate_archive_hash "$BACKUP_ARCHIVE" "${BACKUP_ARCHIVE}.sha256")
if [[ $? -eq 0 ]]; then
    log_message "INFO" "SHA256: $HASH"
else
    log_message "ERROR" "Failed to calculate hash"
    cleanup_temp_files "/tmp/backup_$$"
    exit 1
fi

# Encrypt if requested using library function
if [[ "$ENCRYPT_BACKUP" == "true" ]]; then
    log_message "INFO" "Encrypting backup..."
    echo -e "${YELLOW}You will be prompted for a passphrase. Choose a strong one!${NC}"
    echo "Password requirements:"
    echo "• Minimum 12 characters"
    echo "• Mix of uppercase, lowercase, numbers, and symbols" 
    echo "• Unique and not used elsewhere"
    echo "• Store securely - it CANNOT be recovered"
    echo ""
    
    if encrypt_archive "$BACKUP_ARCHIVE"; then
        BACKUP_ARCHIVE="${BACKUP_ARCHIVE}.gpg"
        log_message "INFO" "Backup encrypted successfully!"
        log_message "INFO" "Encrypted file: $BACKUP_ARCHIVE"
        
        # Calculate hash of encrypted file
        ENCRYPTED_HASH=$(calculate_archive_hash "$BACKUP_ARCHIVE" "${BACKUP_ARCHIVE}.sha256")
        if [[ $? -eq 0 ]]; then
            log_message "INFO" "Encrypted SHA256: $ENCRYPTED_HASH"
        else
            log_message "WARN" "Failed to calculate encrypted hash"
            ENCRYPTED_HASH="[calculation_failed]"
        fi
    else
        log_message "ERROR" "Encryption failed! This is critical for complete mode."
        if [[ "$BACKUP_MODE" == "complete" ]]; then
            log_message "ERROR" "Cannot proceed with unencrypted complete backup"
            cleanup_temp_files "/tmp/backup_$$"
            exit 1
        fi
    fi
fi

# Create restore documentation
cat > "$BACKUP_DOC" << EOF
# Profile Backup and Restore Procedures

**Original SHA256 Hash:** \`$HASH\`  
EOF

if [ "$ENCRYPT_BACKUP" = true ] && [ -f "${BACKUP_ARCHIVE}" ]; then
    cat >> "$BACKUP_DOC" << EOF
**Encrypted SHA256 Hash:** \`$ENCRYPTED_HASH\`  
**Encryption:** GPG AES256 (symmetric)  
EOF
fi

cat >> "$BACKUP_DOC" << EOF
**Backup Date:** $(date '+%Y-%m-%d %H:%M:%S')  
**Archive File:** \`$(basename "$BACKUP_ARCHIVE")\`  
**Archive Size:** $ARCHIVE_SIZE

## ⚠️ SECURITY NOTICE

This backup contains sensitive data including:
- SSH private keys
- GPG private keys  
- Application credentials and tokens
- Kubernetes configurations

**KEEP THIS BACKUP SECURE!**

## Excluded for Security

The following files were intentionally excluded:
- \`.git-credentials\` - Contains plaintext passwords
- \`.aws/credentials\` - AWS access keys
- \`.docker/config.json\` - Docker registry credentials

You should back these up separately with strong encryption if needed.

## Verify Backup Integrity

EOF

if [ "$ENCRYPT_BACKUP" = true ] && [ -f "${BACKUP_ARCHIVE}" ]; then
    cat >> "$BACKUP_DOC" << EOF
For encrypted backup:
\`\`\`bash
echo "$ENCRYPTED_HASH  $(basename "$BACKUP_ARCHIVE")" | sha256sum -c
\`\`\`

To decrypt:
\`\`\`bash
gpg -d $(basename "$BACKUP_ARCHIVE") > ${BACKUP_NAME}.tar.gz
echo "$HASH  ${BACKUP_NAME}.tar.gz" | sha256sum -c
\`\`\`
EOF
else
    cat >> "$BACKUP_DOC" << EOF
\`\`\`bash
echo "$HASH  $BACKUP_NAME.tar.gz" | sha256sum -c
\`\`\`
EOF
fi

cat >> "$BACKUP_DOC" << EOF

## What's Included in This Backup (Mode: $BACKUP_MODE)

### Shell Configurations
- \`.bashrc\`, \`.bash_profile\`, \`.bash_logout\`, \`.profile\`
- \`.zshrc\`, \`.p10k.zsh\` (Zsh and Powerlevel10k configs)

### Development Tools
EOF

if [[ "$BACKUP_MODE" == "complete" ]]; then
    cat >> "$BACKUP_DOC" << EOF
- \`.gitconfig\`, \`.git-credentials\` (Git configuration WITH credentials) ⚠️
EOF
else
    cat >> "$BACKUP_DOC" << EOF  
- \`.gitconfig\` (Git configuration - NO credentials)
EOF
fi

cat >> "$BACKUP_DOC" << EOF
- \`.npmrc\`, \`.yarnrc\` (Node.js package managers)
- \`.cargo/config*\` (Rust configuration)
- \`.bun/\` (Bun runtime)
- \`.flutter\` (Flutter SDK settings)
- \`.pub-cache/\`, \`.dart-tool/\` (Dart/Flutter packages)

### Modern AI/Development Tools
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
- Docker Desktop configurations
- Qt theming (Kvantum, qt5ct, qt6ct)
- Systemd user services
- Flatpak application data
EOF

if [[ "$BACKUP_MODE" == "complete" ]]; then
    cat >> "$BACKUP_DOC" << EOF

### Security & Authentication (⚠️ COMPLETE MODE)
- \`.ssh/\` (SSH keys and known_hosts) ⚠️ HIGH RISK
- \`.gnupg/\` (GPG keys and trust database) ⚠️ HIGH RISK
- \`.pki/\` (PKI certificates) ⚠️ MEDIUM RISK
- \`.kube/\` (Kubernetes configurations) ⚠️ HIGH RISK
- \`.talos/\` (Talos configurations) ⚠️ HIGH RISK
- \`.aws/\` (AWS credentials) ⚠️ HIGH RISK
- \`.docker/\` (Docker registry credentials) ⚠️ MEDIUM RISK
- 1Password, Termius configurations ⚠️ HIGH RISK

**⚠️ CRITICAL: This backup contains sensitive credentials that provide:**
- Full access to your servers and services
- Cloud account access with billing implications  
- Identity impersonation capabilities
- Encryption key access
EOF
else
    cat >> "$BACKUP_DOC" << EOF

### Application Configurations
- \`.config/\` (Most application settings)
- \`.local/share/\` (Application data)
- \`.local/bin/\` (User scripts and binaries)
- Claude AI configurations

### Excluded for Security (Secure Mode)
- SSH private keys, GPG keys (backup separately if needed)
- Cloud credentials (.aws, .docker configs)
- Git stored credentials
- High-risk application credentials
EOF
fi

cat >> "$BACKUP_DOC" << EOF

### System Configurations
- \`.nvidia-settings-rc\` (NVIDIA display settings)
- \`.fonts.conf\`, \`.fonts/\` (Font configurations)
- \`.gtkrc-2.0\` (GTK theme settings)

### Software Inventory
- \`.software_inventory_backup.txt\` (List of installed packages)

## Restore Procedure

### Step 1: Copy and Verify Backup
EOF

if [ "$ENCRYPT_BACKUP" = true ] && [ -f "${BACKUP_ARCHIVE}" ]; then
    cat >> "$BACKUP_DOC" << EOF
\`\`\`bash
# Copy encrypted backup
cp /path/to/external/drive/$(basename "$BACKUP_ARCHIVE") ~/

# Verify and decrypt
echo "$ENCRYPTED_HASH  $(basename "$BACKUP_ARCHIVE")" | sha256sum -c
gpg -d $(basename "$BACKUP_ARCHIVE") > ${BACKUP_NAME}.tar.gz

# Verify decrypted archive
echo "$HASH  ${BACKUP_NAME}.tar.gz" | sha256sum -c
\`\`\`
EOF
else
    cat >> "$BACKUP_DOC" << EOF
\`\`\`bash
# Copy backup
cp /path/to/external/drive/$BACKUP_NAME.tar.gz ~/

# Verify integrity
echo "$HASH  $BACKUP_NAME.tar.gz" | sha256sum -c
\`\`\`
EOF
fi

cat >> "$BACKUP_DOC" << EOF

### Step 2: Extract Backup
\`\`\`bash
cd ~
tar -xzf $BACKUP_NAME.tar.gz

# Securely delete the archive after extraction
shred -vuz $BACKUP_NAME.tar.gz || rm -f $BACKUP_NAME.tar.gz
\`\`\`

### Step 3: Fix Permissions (CRITICAL!)
\`\`\`bash
# SSH - must be exact permissions or SSH will refuse to work
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_* ~/.ssh/config
chmod 644 ~/.ssh/*.pub ~/.ssh/known_hosts ~/.ssh/authorized_keys

# GPG - must be restricted
chmod 700 ~/.gnupg
find ~/.gnupg -type f -exec chmod 600 {} \;
find ~/.gnupg -type d -exec chmod 700 {} \;

# Kubernetes
[ -f ~/.kube/config ] && chmod 600 ~/.kube/config

# Executable permissions for user scripts
[ -d ~/.local/bin ] && chmod +x ~/.local/bin/*
\`\`\`

### Step 4: Restore Missing Credentials

Since sensitive credentials were excluded, you'll need to:

1. **Git credentials**: 
   \`\`\`bash
   # Use SSH instead of HTTPS for git
   git config --global url."git@github.com:".insteadOf "https://github.com/"
   
   # Or use credential manager
   git config --global credential.helper manager
   \`\`\`

2. **Cloud credentials**: Re-authenticate with cloud CLIs
   \`\`\`bash
   aws configure
   gcloud auth login
   az login
   \`\`\`

### Step 5: Review Software Inventory
\`\`\`bash
# View the software that was installed on the old system
less ~/.software_inventory_backup.txt
\`\`\`

### Step 6: Test Critical Services
\`\`\`bash
# Test SSH
ssh -T git@github.com

# Test GPG
gpg --list-secret-keys

# Test git signing (if configured)
echo "test" | gpg --clearsign
\`\`\`

## Security Best Practices

1. **Storage**: Store backups on encrypted external media
2. **Transport**: Use secure methods when transferring backups
3. **Deletion**: Use \`shred\` to securely delete backup files:
   \`\`\`bash
   shred -vuz $BACKUP_NAME.tar.gz
   \`\`\`
4. **Access**: Never store backups on shared or cloud storage without additional encryption
5. **Rotation**: Delete old backups securely after verifying new ones

---
Generated: $(date '+%Y-%m-%d %H:%M:%S')
EOF

# Set secure permissions on documentation using library function
set_secure_permissions "$BACKUP_DOC" "" "600"
set_secure_permissions "$SOFTWARE_LIST" "" "600"

# Clean up all temporary files
cleanup_temp_files "/tmp/backup_$$"

log_message "INFO" "Documentation created: $BACKUP_DOC"

# Enhanced final summary with comprehensive security information
echo ""
echo -e "${GREEN}Secure Backup Complete!${NC}"
echo "========================="
echo "Archive: $BACKUP_ARCHIVE"
echo "Mode: $BACKUP_MODE"
echo "Size: $ARCHIVE_SIZE"

if [[ "$ENCRYPT_BACKUP" == "true" ]]; then
    echo "Encryption: GPG AES256"
    if [[ -n "${ENCRYPTED_HASH:-}" && "$ENCRYPTED_HASH" != "[calculation_failed]" ]]; then
        echo "Encrypted SHA256: $ENCRYPTED_HASH"
    fi
    echo "Original SHA256: $HASH"
else
    echo "SHA256: $HASH"
    if [[ "$BACKUP_MODE" == "complete" ]]; then
        echo -e "${RED}ERROR: Complete mode REQUIRES encryption!${NC}"
    else
        echo -e "${YELLOW}WARNING: Backup is NOT encrypted!${NC}"
    fi
fi

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

echo -e "${RED}CRITICAL SECURITY REMINDERS:${NC}"
if [[ "$BACKUP_MODE" == "complete" ]]; then
    echo "1. ⚠️  COMPLETE MODE: Contains ALL credentials (SSH, GPG, cloud)"
    echo "2. 🔒 ENCRYPTED: Must remain encrypted at all times"
    echo "3. 📦 STORAGE: Use encrypted external drive, never cloud storage"
    echo "4. 🔑 PASSWORD: Store encryption password securely separately"
    echo "5. ⏰ ACCESS: Limit who has access to this backup"
else
    echo "1. ✅ SECURE MODE: High-risk credentials excluded"
    echo "2. 🔐 ENCRYPTION: $([ "$ENCRYPT_BACKUP" = true ] && echo "Enabled (recommended)" || echo "Disabled (consider enabling)")"
    echo "3. 📁 CREDENTIALS: Backup SSH/GPG keys separately if needed"
fi
echo "4. 🔍 VERIFICATION: Always verify hash before using backup"
echo "5. 🗑️  CLEANUP: Securely delete backup after successful restore"
echo ""

if [[ "$ENCRYPT_BACKUP" != "true" ]]; then
    echo -e "${YELLOW}RECOMMENDATION: Encrypt this backup for additional security:${NC}"
    echo "   gpg -c $BACKUP_ARCHIVE"
    echo ""
fi

echo "Verification command:"
if [[ "$ENCRYPT_BACKUP" == "true" && -n "${ENCRYPTED_HASH:-}" ]]; then
    echo "   echo \"$ENCRYPTED_HASH  $(basename "$BACKUP_ARCHIVE")\" | sha256sum -c"
else
    echo "   echo \"$HASH  $BACKUP_NAME.tar.gz\" | sha256sum -c"
fi

log_message "INFO" "Secure backup completed successfully with mode: $BACKUP_MODE"