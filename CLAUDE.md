# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Repository Purpose

Custom tools and scripts for system administration, focusing on security and usability.

## Critical Security Requirement

**Before all commit/push activity, code MUST be audited to ensure:**
- Adherence to security best practices
- No opportunities for unintended exposure are created
- If security risks are inherent to the tool's function:
  - User is warned about the risks
  - Clear guidance provided on avoiding exposure
  - Secure alternatives offered where possible

## Current Tools

### Backup System
1. **Backup UI (backup-ui)** - Terminal interface for backup/restore operations
   - Written in Rust with ratatui framework
   - Provides intuitive menu-driven interface
   - Handles both secure and complete backup modes
   - Includes selective restore functionality

2. **backup-profile-enhanced.sh** - Convenience-focused, includes all credentials
   - Use case: Immediate OS reinstall (same day/week)
   - Includes sensitive files for quick restoration
   - Must be securely deleted after use

3. **backup-profile-secure.sh** - Security-focused, excludes credentials
   - Use case: Long-term storage, sharing, or uncertainty
   - Excludes .git-credentials, .aws/credentials, etc.
   - Offers GPG encryption
   - Creates files with 600 permissions

4. **backup-noninteractive.sh** - Automation wrapper for TUI integration
   - Runs without user interaction
   - Used by the TUI to execute backups
   - Supports both secure and complete modes

## Development Guidelines

1. **Always perform security audit before commits**
2. **Document security implications in code comments**
3. **Provide both convenient and secure versions when trade-offs exist**
4. **Default to secure practices (restrictive permissions, encryption options)**
5. **Warn users prominently about security risks**

## Security Patterns to Follow

```bash
# Secure file creation
touch "$FILE"
chmod 600 "$FILE"
echo "content" > "$FILE"

# Security warnings
echo -e "${RED}==== SECURITY WARNING ====${NC}"
echo "This script will handle sensitive data..."

# Secure deletion
shred -vuz "$FILE" 2>/dev/null || rm -f "$FILE"

# Permission checks
if [ -f "$HOME/.ssh/id_rsa" ]; then
    chmod 600 "$HOME/.ssh/id_rsa"
fi
```

## Testing Requirements

Before committing backup scripts:
1. Test with AND without sensitive files present
2. Verify file permissions on all outputs
3. Test encryption options
4. Verify secure deletion works
5. Check all warnings display properly