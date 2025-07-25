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

**Usage:**
```bash
./backup-profile-enhanced.sh
```

**Output:**
- `profile_backup_[timestamp].tar.gz` - Compressed backup archive
- `profile_backup_[timestamp].log` - Detailed backup log
- `profile_backup_[timestamp]_software.txt` - Software inventory
- `restore_profile_backup_[timestamp].md` - Restoration guide with hash

## License

MIT