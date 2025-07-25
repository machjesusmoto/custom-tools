# Custom Tools

A collection of custom tools and scripts for system administration and development.

## Tools

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