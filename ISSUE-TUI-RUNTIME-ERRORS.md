# Critical TUI Runtime Errors: Path Resolution and UTF-8 String Slicing

## Bug Report

Two critical runtime errors prevent the Backup UI from functioning properly in production use.

### Issue 1: Directory-Agnostic Launch Failure

**Description:** The application fails to find its configuration file when launched from any directory other than the project/build directory.

**Expected Behavior:** The application should locate its configuration file regardless of the current working directory.

**Actual Behavior:** Application exits with "Failed to read config file" error.

**Error Message:**
```
Failed to read config file: backup-config.json
```

**Root Cause:** The config loader only checks for `backup-config.json` in the current working directory.

### Issue 2: UTF-8 String Slicing Panic

**Description:** The application panics when attempting to display the backup workflow screen due to improper handling of multi-byte UTF-8 characters.

**Expected Behavior:** The UI should properly handle and display Unicode characters (checkmarks, arrows, etc.).

**Actual Behavior:** Application crashes with a panic when entering the backup workflow.

**Error Message:**
```
[2025-08-04T17:29:01Z INFO  backup_ui] Starting Backup UI v0.1.0

thread 'main' panicked at src/ui/screens/backup_mode_selection.rs:120:31:
byte index 2 is not a char boundary; it is inside '✓' (bytes 0..3) of `✓ Configuration files and settings`
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
```

**Root Cause:** The code is attempting to slice a string at byte position 2, which falls in the middle of the 3-byte UTF-8 character '✓'.

### Environment

- **OS:** Arch Linux (CachyOS)
- **Rust Version:** Latest stable
- **Terminal:** Various (issue occurs across different terminals)
- **Build Directory:** `/home/dtaylor/GitHub/custom-tools`
- **Test Directory:** `/home/dtaylor/testing/`

### Steps to Reproduce

**Issue 1:**
1. Build the application with `cargo build --release`
2. Navigate to any directory outside the project: `cd ~`
3. Run the application: `backup-ui`
4. Observe the config file error

**Issue 2:**
1. Build and run from the project directory
2. Select "Start Backup" from the main menu
3. Application panics immediately upon entering backup mode selection

### Severity

**Critical** - These issues completely prevent normal usage of the application.

### Proposed Solutions

**Issue 1:** Implement proper config file search paths:
- Check multiple standard locations (current dir, ~/.config/backup-manager/, /etc/backup-manager/)
- Use the `dirs` crate to find appropriate config directories
- Bundle config with the binary or generate it on first run

**Issue 2:** Fix string slicing to respect UTF-8 boundaries:
- Use `.chars()` iterator instead of byte indexing
- Replace string slicing operations with Unicode-aware methods
- Consider using `unicode-width` crate for proper text layout calculations

### Additional Context

Both issues were discovered during initial production testing. The application works in development but fails in real-world deployment scenarios.

---

**To create this issue on GitHub:**

1. Go to https://github.com/dtaylor/custom-tools/issues/new
2. Copy the title: "Critical TUI Runtime Errors: Path Resolution and UTF-8 String Slicing"
3. Paste the content above into the issue body
4. Add labels: `bug`, `critical`, `runtime-error`, `tui`
5. Submit the issue