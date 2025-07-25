#!/bin/bash

# Secure Profile Backup Script with encryption and security warnings

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# ANSI color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="profile_backup_$BACKUP_DATE"
BACKUP_ARCHIVE="$HOME/${BACKUP_NAME}.tar.gz"
BACKUP_LOG="$HOME/${BACKUP_NAME}.log"
BACKUP_DOC="$HOME/restore_${BACKUP_NAME}.md"
SOFTWARE_LIST="$HOME/${BACKUP_NAME}_software.txt"

# Security warning
echo -e "${RED}==== SECURITY WARNING ====${NC}"
echo "This script will backup sensitive data including:"
echo "  - SSH private keys (~/.ssh/)"
echo "  - GPG private keys (~/.gnupg/)"
echo "  - Application tokens and credentials"
echo "  - Git credentials (if stored)"
echo ""
echo -e "${YELLOW}The backup will contain UNENCRYPTED sensitive data!${NC}"
echo ""
read -p "Do you want to continue? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Backup cancelled."
    exit 0
fi

echo ""
read -p "Would you like to encrypt the backup with GPG? (recommended) (y/N): " -n 1 -r
echo
ENCRYPT_BACKUP=false
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ENCRYPT_BACKUP=true
fi

# Initialize log file with restricted permissions
touch "$BACKUP_LOG"
chmod 600 "$BACKUP_LOG"

echo "Profile Backup Log - $BACKUP_DATE" > "$BACKUP_LOG"
echo "======================================" >> "$BACKUP_LOG"
echo "" >> "$BACKUP_LOG"

# Function to log messages
log() {
    echo "$1" | tee -a "$BACKUP_LOG"
}

log "Starting secure profile backup..."
log "Archive: $BACKUP_ARCHIVE"
log "Encryption: $ENCRYPT_BACKUP"
log ""

# Create software inventory
echo "Creating software inventory..."
{
    echo "# Software Inventory - $BACKUP_DATE"
    echo ""
    
    echo "## System Packages (pacman)"
    echo '```'
    pacman -Qqe
    echo '```'
    echo ""
    
    echo "## AUR Packages"
    echo '```'
    pacman -Qqm
    echo '```'
    echo ""
    
    if command -v flatpak &>/dev/null; then
        echo "## Flatpak Applications"
        echo '```'
        flatpak list --app --columns=application
        echo '```'
        echo ""
    fi
    
    echo "## Development Tools"
    echo ""
    
    if [ -d "$HOME/.cargo/bin" ]; then
        echo "### Rust/Cargo Tools"
        echo '```'
        ls -1 "$HOME/.cargo/bin" | grep -v "^cargo$\|^rustc$\|^rustup$"
        echo '```'
        echo ""
    fi
    
    if command -v npm &>/dev/null; then
        echo "### Global NPM Packages"
        echo '```'
        npm list -g --depth=0 2>/dev/null | grep -v "npm@" | tail -n +2 | sed 's/[├─└]//g' | sed 's/^ *//'
        echo '```'
        echo ""
    fi
    
    if command -v pip &>/dev/null; then
        echo "### Python Packages (user)"
        echo '```'
        pip list --user --format=freeze 2>/dev/null
        echo '```'
        echo ""
    fi
    
    echo "## Shell Tools in PATH"
    echo "Tools found in .config/*/bin and .local/bin:"
    echo '```'
    find ~/.local/bin ~/.config/*/bin -type f -executable 2>/dev/null | sed "s|$HOME/||" | sort
    echo '```'
    
} > "$SOFTWARE_LIST"

log "Software inventory created: $SOFTWARE_LIST"

# Files to backup (EXCLUDING .git-credentials for security!)
DOTFILES=(
    .bashrc .bash_profile .bash_logout .profile
    .zshrc .p10k.zsh .gitconfig
    .npmrc .yarnrc .nvidia-settings-rc .fonts.conf
    .gtkrc-2.0 .claude.json .flutter
)

# Directories to backup
DIRECTORIES=(
    .config .local/share .ssh .gnupg .kube .talos
    .cargo/config* .npm/npmrc .yarn/config .bun
    .claude .vscode-oss .pub-cache .dart-tool
    .fonts .pki .local/bin
)

# Warn about excluded sensitive files
log ""
log "SECURITY: Excluding .git-credentials (contains plaintext passwords)"

# Check for other sensitive files
if [ -f "$HOME/.aws/credentials" ]; then
    log "WARNING: Found .aws/credentials - consider backing up separately with encryption"
fi
if [ -f "$HOME/.docker/config.json" ]; then
    log "WARNING: Found .docker/config.json - may contain auth tokens"
fi

# Log files being backed up
log ""
log "BACKING UP DOTFILES:"
for file in "${DOTFILES[@]}"; do
    if [ -f "$HOME/$file" ]; then
        log "  [FILE] $file"
    fi
done

log ""
log "BACKING UP DIRECTORIES:"
for dir in "${DIRECTORIES[@]}"; do
    # Handle glob patterns
    for path in $HOME/$dir; do
        if [ -d "$path" ]; then
            log "  [DIR] ${path#$HOME/}"
            # Warn about sensitive directories
            case "$path" in
                */.ssh)
                    log "    ${YELLOW}⚠ Contains SSH private keys${NC}"
                    ;;
                */.gnupg)
                    log "    ${YELLOW}⚠ Contains GPG private keys${NC}"
                    ;;
                */.kube)
                    log "    ${YELLOW}⚠ May contain cluster credentials${NC}"
                    ;;
            esac
        fi
    done
done

# Add software inventory to backup
cp "$SOFTWARE_LIST" "$HOME/.software_inventory_backup.txt"

log ""
log "Creating archive with exclusions..."

# Create archive with restricted permissions
umask 077  # Ensure created files are only readable by owner

tar -czf "$BACKUP_ARCHIVE" \
    --exclude="*.cache" \
    --exclude="*Cache*" \
    --exclude="*.log" \
    --exclude="node_modules" \
    --exclude=".local/share/Trash" \
    --exclude=".config/*/Cache" \
    --exclude=".config/*/cache" \
    --exclude=".config/chromium" \
    --exclude=".config/google-chrome" \
    --exclude=".mozilla/firefox/*/cache*" \
    --exclude=".yarn/cache" \
    --exclude=".npm/_cacache" \
    --exclude=".cargo/registry/cache" \
    --exclude=".cache" \
    --exclude=".var/app/*/cache" \
    --exclude=".git-credentials" \
    --exclude=".aws/credentials" \
    --exclude=".docker/config.json" \
    -C "$HOME" \
    "${DOTFILES[@]}" \
    .software_inventory_backup.txt \
    .config .local/share .local/bin .ssh .gnupg .kube .talos \
    .cargo/config* .npm/npmrc .yarn/config .bun \
    .claude .vscode-oss .pub-cache .dart-tool \
    .fonts .pki 2>/dev/null || true

# Set secure permissions on archive
chmod 600 "$BACKUP_ARCHIVE"

# Remove temporary file
rm -f "$HOME/.software_inventory_backup.txt"

ARCHIVE_SIZE=$(du -h "$BACKUP_ARCHIVE" | cut -f1)
log ""
log "Archive created successfully!"
log "Size: $ARCHIVE_SIZE"

# Calculate hash of unencrypted archive
log ""
log "Calculating SHA256 hash..."
HASH=$(sha256sum "$BACKUP_ARCHIVE" | cut -d' ' -f1)
log "SHA256: $HASH"

# Encrypt if requested
if [ "$ENCRYPT_BACKUP" = true ]; then
    log ""
    log "Encrypting backup..."
    echo -e "${YELLOW}You will be prompted for a passphrase. Choose a strong one!${NC}"
    
    if gpg --symmetric --cipher-algo AES256 "$BACKUP_ARCHIVE"; then
        # Remove unencrypted version
        shred -vuz "$BACKUP_ARCHIVE" 2>/dev/null || rm -f "$BACKUP_ARCHIVE"
        BACKUP_ARCHIVE="${BACKUP_ARCHIVE}.gpg"
        log "Backup encrypted successfully!"
        log "Encrypted file: $BACKUP_ARCHIVE"
        
        # Calculate hash of encrypted file
        ENCRYPTED_HASH=$(sha256sum "$BACKUP_ARCHIVE" | cut -d' ' -f1)
        log "Encrypted SHA256: $ENCRYPTED_HASH"
    else
        log "ERROR: Encryption failed! Unencrypted backup remains."
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

## What's Included in This Backup

### Shell Configurations
- \`.bashrc\`, \`.bash_profile\`, \`.bash_logout\`, \`.profile\`
- \`.zshrc\`, \`.p10k.zsh\` (Zsh and Powerlevel10k configs)

### Development Tools
- \`.gitconfig\` (Git configuration - NO credentials)
- \`.npmrc\`, \`.yarnrc\` (Node.js package managers)
- \`.cargo/config*\` (Rust configuration)
- \`.bun/\` (Bun runtime)
- \`.flutter\` (Flutter SDK settings)
- \`.pub-cache/\`, \`.dart-tool/\` (Dart/Flutter packages)

### Security & Authentication
- \`.ssh/\` (SSH keys and known_hosts) ⚠️
- \`.gnupg/\` (GPG keys and trust database) ⚠️
- \`.pki/\` (PKI certificates) ⚠️
- \`.kube/\` (Kubernetes configurations) ⚠️
- \`.talos/\` (Talos configurations) ⚠️

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

# Set secure permissions on documentation
chmod 600 "$BACKUP_DOC"
chmod 600 "$SOFTWARE_LIST"

log ""
log "Documentation created: $BACKUP_DOC"

# Final summary with security reminder
echo ""
echo -e "${GREEN}Secure Backup Complete!${NC}"
echo "======================"
echo "Archive: $BACKUP_ARCHIVE"
echo "Size: $ARCHIVE_SIZE"
if [ "$ENCRYPT_BACKUP" = true ]; then
    echo "Encryption: GPG AES256"
    echo "SHA256: $ENCRYPTED_HASH"
else
    echo "SHA256: $HASH"
    echo -e "${YELLOW}WARNING: Backup is NOT encrypted!${NC}"
fi
echo "Log: $BACKUP_LOG"
echo "Docs: $BACKUP_DOC"
echo "Software: $SOFTWARE_LIST"
echo ""
echo -e "${RED}SECURITY REMINDERS:${NC}"
echo "1. This backup contains sensitive data (SSH/GPG keys)"
echo "2. Store it securely (encrypted external drive recommended)"
echo "3. Set proper permissions after restore (see documentation)"
echo "4. Verify hash before using: echo \"$HASH  $BACKUP_NAME.tar.gz\" | sha256sum -c"
if [ "$ENCRYPT_BACKUP" != true ]; then
    echo ""
    echo -e "${YELLOW}Consider encrypting this backup:${NC}"
    echo "   gpg -c $BACKUP_ARCHIVE"
fi