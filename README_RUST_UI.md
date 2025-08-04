# Backup & Restore System - Rust Terminal UI

A comprehensive terminal user interface for the backup and restore system, built with Rust and ratatui.

## Prerequisites

The system automatically verifies prerequisites during compilation. Required tools:
- Bash shell (5.0+)
- GNU tar (1.30+)
- Gzip compression (1.10+)

Optional tools for full functionality:
- GPG (for encryption features)
- shred (for secure file deletion)
- Package managers (for software inventory)

To skip prerequisite checks during build (e.g., in CI):
```bash
SKIP_PREREQ_CHECKS=1 cargo build --release
```

## Features

### Core Functionality
- **Interactive Terminal UI**: Clean, intuitive interface built with ratatui
- **Secure Password Handling**: Memory-safe password input with automatic clearing
- **Two Backup Modes**:
  - **Secure Mode**: Excludes sensitive credentials (SSH keys, GPG keys, etc.)
  - **Complete Mode**: Includes all files with mandatory encryption
- **Selective Restoration**: Choose specific files to restore from archives
- **Progress Tracking**: Real-time progress bars for backup/restore operations
- **Conflict Detection**: Identifies and warns about file conflicts during restore

### Security Features
- **Password Strength Validation**: Real-time password strength checking
- **Secure Memory Management**: Automatic memory clearing for sensitive data
- **Encryption Support**: Integration with GPG for secure backups
- **Security Level Indicators**: Visual indicators for file sensitivity levels

### User Interface
- **Keyboard Navigation**: Full keyboard navigation with intuitive shortcuts
- **Responsive Design**: Works on different terminal sizes
- **Color-Coded Interface**: Security levels and status indicated by colors
- **Contextual Help**: Built-in help system accessible via Ctrl+H
- **Error Handling**: Comprehensive error messages and recovery guidance

## Project Structure

```
src/
├── main.rs                     # Application entry point
├── core/                       # Core application logic
│   ├── app.rs                  # Main application controller
│   ├── config.rs               # Configuration management
│   ├── security.rs             # Security utilities
│   ├── state.rs                # Application state management
│   └── types.rs                # Type definitions
├── ui/                         # User interface components
│   ├── terminal.rs             # Terminal management
│   ├── components.rs           # Reusable UI components
│   ├── widgets.rs              # Custom widgets
│   └── screens/                # Individual screens
│       ├── main_menu.rs
│       ├── backup_mode_selection.rs
│       ├── backup_item_selection.rs
│       ├── backup_password.rs
│       ├── backup_progress.rs
│       ├── backup_complete.rs
│       ├── restore_archive_selection.rs
│       ├── restore_password.rs
│       ├── restore_item_selection.rs
│       ├── restore_progress.rs
│       ├── restore_complete.rs
│       ├── help.rs
│       └── error.rs
└── backend/                    # Backend integration
    └── mod.rs                  # Integration with bash scripts
```

## Dependencies

- **ratatui 0.28**: Modern terminal UI framework
- **crossterm 0.28**: Cross-platform terminal functionality
- **tokio**: Async runtime for non-blocking operations
- **serde & serde_json**: Configuration serialization
- **anyhow & thiserror**: Error handling
- **zeroize**: Secure memory clearing
- **sha2**: Password hashing
- **chrono**: Date/time handling
- **clap**: Command-line argument parsing
- **dirs**: Home directory detection

## Building and Running

### Prerequisites
- Rust 1.70+ 
- Cargo package manager

### Build
```bash
cargo build --release
```

### Run
```bash
cargo run -- --config backup-config.json
```

### Command Line Options
```bash
# Use custom config file
cargo run -- --config my-backup-config.json

# Specify output directory
cargo run -- --output /path/to/backups

# Enable debug logging
cargo run -- --debug
```

## Usage

### Main Menu
- `1` or `b`: Start backup workflow
- `2` or `r`: Start restore workflow
- `Ctrl+H`: Show help
- `q` or `Esc`: Quit

### Navigation
- `↑↓` or `j/k`: Navigate lists
- `Space`: Toggle item selection
- `A`: Select all items
- `N`: Deselect all items
- `Enter`: Confirm/Continue
- `Esc`: Go back
- `Ctrl+C`: Force quit

### Backup Workflow
1. **Mode Selection**: Choose between Secure or Complete mode
2. **Item Selection**: Select files and directories to backup
3. **Password Input**: Enter encryption password (Complete mode only)
4. **Progress Tracking**: Monitor backup progress
5. **Completion**: Review backup results

### Restore Workflow
1. **Archive Selection**: Choose backup archive to restore from
2. **Password Input**: Enter decryption password (if encrypted)
3. **Item Selection**: Choose specific items to restore
4. **Conflict Resolution**: Review file conflicts
5. **Progress Tracking**: Monitor restore progress
6. **Completion**: Review restore results

## Security Considerations

### Password Security
- Passwords are never stored in memory longer than necessary
- Memory is automatically cleared after use
- Password strength is validated in real-time
- No password echoing to terminal

### File Security
- Secure mode excludes sensitive credential files
- Complete mode requires encryption for sensitive data
- Security levels are visually indicated
- Warnings provided for high-security files

### Integration Security
- Backend integration uses environment variables for passwords
- No temporary password files created
- Secure subprocess communication

## Backend Integration

The UI integrates with the existing bash-based backup system through:

- **Configuration Loading**: Reads `backup-config.json` for file categories
- **Script Execution**: Calls `backup-lib.sh` functions via subprocess
- **Progress Monitoring**: Real-time output parsing for progress updates
- **Error Handling**: Captures and displays script errors

## Future Enhancements

- **Archive Browsing**: Detailed archive content inspection
- **Scheduled Backups**: Cron integration for automated backups
- **Remote Storage**: Support for cloud storage providers
- **Compression Options**: Selectable compression algorithms
- **Incremental Backups**: Support for differential backups
- **Backup Verification**: Archive integrity checking
- **Multi-profile Support**: Different backup configurations
- **Logging Integration**: Detailed operation logging

## Testing

```bash
# Run tests
cargo test

# Run with coverage
cargo test --coverage
```

## Performance

- **Memory Usage**: Efficient memory management with automatic cleanup
- **Responsiveness**: Non-blocking UI with async operations
- **Scalability**: Handles large file lists with scrolling and pagination
- **Resource Management**: Minimal CPU usage during idle states

This Rust UI provides a modern, secure, and user-friendly interface to the existing backup system while maintaining full compatibility with the bash-based backend.