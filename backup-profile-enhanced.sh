#!/bin/bash

# Enhanced Profile Backup Script with software inventory

BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="profile_backup_$BACKUP_DATE"
BACKUP_ARCHIVE="$HOME/${BACKUP_NAME}.tar.gz"
BACKUP_LOG="$HOME/${BACKUP_NAME}.log"
BACKUP_DOC="$HOME/restore_${BACKUP_NAME}.md"
SOFTWARE_LIST="$HOME/${BACKUP_NAME}_software.txt"

# Initialize log file
echo "Profile Backup Log - $BACKUP_DATE" > "$BACKUP_LOG"
echo "======================================" >> "$BACKUP_LOG"
echo "" >> "$BACKUP_LOG"

# Function to log messages
log() {
    echo "$1" | tee -a "$BACKUP_LOG"
}

log "Starting enhanced profile backup..."
log "Archive: $BACKUP_ARCHIVE"
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

# Files to backup
DOTFILES=(
    .bashrc .bash_profile .bash_logout .profile
    .zshrc .p10k.zsh .gitconfig .git-credentials
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

# Log files being backed up
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
        fi
    done
done

# Add software inventory to backup
cp "$SOFTWARE_LIST" "$HOME/.software_inventory_backup.txt"

log ""
log "Creating archive with exclusions..."

# Create archive directly with exclusions
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
    -C "$HOME" \
    "${DOTFILES[@]}" \
    .software_inventory_backup.txt \
    .config .local/share .local/bin .ssh .gnupg .kube .talos \
    .cargo/config* .npm/npmrc .yarn/config .bun \
    .claude .vscode-oss .pub-cache .dart-tool \
    .fonts .pki 2>/dev/null || true

# Remove temporary file
rm -f "$HOME/.software_inventory_backup.txt"

ARCHIVE_SIZE=$(du -h "$BACKUP_ARCHIVE" | cut -f1)
log ""
log "Archive created successfully!"
log "Size: $ARCHIVE_SIZE"

# Calculate hash
log ""
log "Calculating SHA256 hash..."
HASH=$(sha256sum "$BACKUP_ARCHIVE" | cut -d' ' -f1)
log "SHA256: $HASH"

# Create restore documentation
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
EOF

log ""
log "Documentation created: $BACKUP_DOC"

# Final summary
echo ""
echo "Enhanced Backup Complete!"
echo "========================"
echo "Archive: $BACKUP_ARCHIVE"
echo "Size: $ARCHIVE_SIZE"
echo "SHA256: $HASH"
echo "Log: $BACKUP_LOG"
echo "Docs: $BACKUP_DOC"
echo "Software: $SOFTWARE_LIST"
echo ""
echo "Next steps:"
echo "1. Verify: echo \"$HASH  $BACKUP_NAME.tar.gz\" | sha256sum -c"
echo "2. Copy all files to external storage before reinstalling"
echo "3. Review $SOFTWARE_LIST to prepare for software reinstallation"