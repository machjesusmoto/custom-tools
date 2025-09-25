# Custom Tools

A collection of custom tools and scripts for system administration and development.

## Which Backup Script Should I Use?

```
┌─────────────────────────────────────┐
│   How will you use this backup?    │
└────────────┬────────────────────────┘
             │
             ├─── Immediate use (OS reinstall today/this week)
             │    └─── You control the backup at all times?
             │         └─── YES → Use backup-profile-enhanced.sh
             │                    (Convenient, includes everything)
             │
             └─── Long-term storage / "just in case"
                  └─── Use backup-profile-secure.sh
                       (Excludes sensitive credentials, supports encryption)
```

### Quick Decision Guide:
- **Installing new distro this weekend?** → `backup-profile-enhanced.sh`
- **Making a backup "just in case"?** → `backup-profile-secure.sh`
- **Giving backup to someone else?** → `backup-profile-secure.sh` (with encryption!)
- **Storing for more than a week?** → `backup-profile-secure.sh`
- **Might upload to cloud someday?** → `backup-profile-secure.sh`

## Installation

### Prerequisites
The backup system automatically checks for prerequisites during both build and runtime:

**Required:**
- Bash shell (5.0+)
- GNU tar (1.30+)
- Gzip compression (1.10+)

**Optional (for full functionality):**
- GPG (for encryption)
- shred (for secure deletion)
- Package managers (pacman, flatpak, npm, pip, cargo)
- Rust/Cargo (for building the terminal UI)

### Quick Install
```bash
# Run the installation script
./install.sh

# Or build from source (UI only)
cargo build --release
```

The installer will:
- Check all prerequisites
- Install scripts to `~/.local/bin`
- Build the Rust UI (if Cargo is available)
- Create convenient command aliases

### Build-time Checks
When building the Rust UI with `cargo build`, prerequisites are automatically verified. To skip checks (e.g., in CI):
```bash
SKIP_PREREQ_CHECKS=1 cargo build --release
```

## Tools

### Backup UI (Terminal User Interface)

A modern terminal interface for managing backups and restores with an intuitive menu-driven system.

**Features:**
- Interactive menu navigation with keyboard shortcuts
- Visual backup mode selection (Secure vs Complete)
- Item selection with categories and descriptions
- Real-time progress tracking
- Password-protected archives support
- Selective restore capabilities
- Comprehensive error handling

**Installation:**
```bash
# Install the UI and scripts
./install-backup-ui.sh

# Or build from source
cargo build --release
```

**Usage:**
```bash
# Run the UI
backup-ui

# With debug output
backup-ui --debug

# Specify output directory
backup-ui --output /path/to/backups
```

**Keyboard Controls:**
- Arrow keys or `j`/`k` - Navigate menus
- Space - Toggle item selection
- Enter - Confirm selection
- `a` - Select all items
- `n` - Select none
- `q` or Esc - Go back/quit
- `?` - Show help

### backup-profile-enhanced.sh

An enhanced profile backup script that creates comprehensive backups of user configurations, dotfiles, and keys with detailed restoration documentation.

**Features:**
- Backs up all dotfiles and configuration directories
- Creates detailed software inventory
- Generates SHA256 hash for integrity verification
- Produces comprehensive restore documentation
- Excludes cache directories to minimize backup size
- Creates detailed logs of all backed up items

**⚠️ Security Note:** This version includes sensitive files like `.git-credentials`. Use `backup-profile-secure.sh` for better security.

**Usage:**
```bash
./backup-profile-enhanced.sh
```

### backup-noninteractive.sh

A non-interactive wrapper script designed for automation and TUI integration.

**Features:**
- Runs without user prompts (ideal for automation)
- Supports both secure and complete backup modes
- Automatically selects appropriate configuration files
- Sets restrictive permissions on output archives
- Provides clear progress output

**Usage:**
```bash
# Secure mode (default)
./backup-noninteractive.sh secure

# Complete mode (includes sensitive files)
./backup-noninteractive.sh complete

# With custom output directory
BACKUP_DIR=/path/to/backups ./backup-noninteractive.sh secure
```

### backup-profile-secure.sh

A security-focused version of the backup script with encryption support and enhanced security features.

**Security Features:**
- **Excludes sensitive files** (`.git-credentials`, `.aws/credentials`, `.docker/config.json`)
- **Optional GPG encryption** with AES256
- **Secure file permissions** (600) on all output files
- **Security warnings** before backup
- **Detailed security documentation**

**Usage:**
```bash
./backup-profile-secure.sh
```

The script will:
1. Warn about sensitive data being backed up
2. Offer to encrypt the backup with GPG
3. Create files with restricted permissions (owner-only)
4. Provide detailed restore instructions with security notes

**Output (both versions):**
- `profile_backup_[timestamp].tar.gz` - Compressed backup archive
- `profile_backup_[timestamp].tar.gz.gpg` - Encrypted archive (if encryption enabled)
- `profile_backup_[timestamp].log` - Detailed backup log
- `profile_backup_[timestamp]_software.txt` - Software inventory
- `restore_profile_backup_[timestamp].md` - Restoration guide with hash

## Security Recommendations

1. **Use the secure version** (`backup-profile-secure.sh`) for production backups
2. **Always encrypt** backups containing SSH/GPG keys
3. **Store securely** on encrypted external drives
4. **Verify hashes** before restoring
5. **Delete securely** using `shred` command

## License

MIT