# QUICK REFERENCE - Custom Tools

Quick command reference for custom backup and disaster recovery tools.

## Build and Installation

```bash
# Build Rust TUI application
cargo build --release

# Install tools and scripts  
./install.sh

# Test installation
backup-ui --help
```

## Testing

```bash
# Run all tests
./test-comprehensive.sh

# Security-focused tests
./test-secure.sh

# TUI interface tests  
./test-tui.sh

# Enhanced backup tests
./test-enhanced.sh
```

## Backup Operations

### TUI Application
```bash
# Launch backup UI
backup-ui

# Direct backup (secure mode)
./backup-profile-secure.sh

# Direct backup (enhanced mode)  
./backup-profile-enhanced.sh

# Non-interactive backup
./backup-noninteractive.sh --secure
```

### Configuration
```bash
# Edit backup configuration
nano backup-config.json

# View current settings
cat backup-config.json | jq
```

## Security Guidelines

### Secure Mode (Long-term storage)
- ✅ Excludes sensitive credentials
- ✅ GPG encryption available
- ✅ Restrictive permissions (600/700)
- ✅ Safe for sharing/archiving

### Enhanced Mode (Immediate restore)
- ⚠️ Includes all credentials  
- ⚠️ Use only for same-day restore
- ⚠️ Must be securely deleted after use
- ⚠️ Higher security risk

## Key Files

### Configuration
- `backup-config.json` - Backup settings
- `Cargo.toml` - Rust project configuration
- `build.rs` - Build script

### Scripts
- `backup-profile-secure.sh` - Security-focused backup
- `backup-profile-enhanced.sh` - Convenience backup
- `backup-noninteractive.sh` - Automation wrapper
- `install.sh` - Installation script

### Source Code
- `src/main.rs` - Application entry point
- `src/ui/` - TUI interface components
- `src/core/` - Core functionality
- `src/disaster_recovery.rs` - DR operations

## Common Tasks

### Development
```bash
# Format code
cargo fmt

# Lint code
cargo clippy

# Run tests
cargo test
```

### Backup Management
```bash
# Secure backup with encryption
./backup-profile-secure.sh --encrypt

# Quick enhanced backup
./backup-profile-enhanced.sh --quick

# Verify backup integrity
./scripts/verify_backup.sh
```

### TUI Navigation
- **Tab/Shift+Tab**: Navigate between elements
- **Enter**: Select/Confirm  
- **Esc**: Cancel/Go back
- **q**: Quit application
- **Arrow keys**: Navigate menus

## Security Warnings

🔒 **Always audit security implications before commits**  
⚠️ **Enhanced mode includes sensitive credentials**  
🛡️ **Default to secure mode for long-term storage**  
🔍 **Review backup contents before distribution**