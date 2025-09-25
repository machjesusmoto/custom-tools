# Custom Tools Script Index
*Version: 1.0.0*
*Last Updated: August 15, 2025*
*Location: ~/projects/custom-tools/*

## Overview

This directory contains all custom scripts and tools that were previously scattered in the home directory. Scripts are now organized by category for better maintainability and version control.

## Directory Structure

```
custom-tools/
├── scripts/
│   ├── claude/          # Claude AI integration scripts
│   ├── obsidian/        # Obsidian vault management
│   ├── network/         # Network configuration and monitoring
│   ├── system/          # System setup and services
│   ├── cleanup/         # Cleanup and analysis tools
│   └── migration/       # Migration and reorganization scripts
├── documentation/       # Related documentation
└── SCRIPT_INDEX.md     # This file
```

## Script Categories

### Claude Scripts (`scripts/claude/`)
- `claude_exit_routine.sh` - Session export and preservation
- `claude_optimizer.py` - Claude optimization utilities
- `claude_optimizer_secure.py` - Secure version of optimizer
- `setup_superclaude.sh` - SuperClaude framework setup
- `update_claude_dir.sh` - Update Claude directory structure
- `test-context7.sh` - Test Context7 MCP integration

### Obsidian Scripts (`scripts/obsidian/`)
- `sync_docs_to_obsidian.sh` - Sync documentation to Obsidian vault

### Network Scripts (`scripts/network/`)
- `check-network-status.sh` - Network connectivity checker
- `optimize-network.sh` - Network optimization settings
- `setup-firewall.sh` - Firewall configuration

### System Scripts (`scripts/system/`)
- `install-services.sh` - System service installation

### Cleanup Scripts (`scripts/cleanup/`)
- `analyze_cleanup.py` - Analyze files for cleanup
- `final_cleanup_report.py` - Generate cleanup reports

### Migration Scripts (`scripts/migration/`)
- `reorganize_tools.sh` - Tool reorganization script
- `update_paths.sh` - Path update utilities
- `update_paths_improved.sh` - Improved path updater
- `verify_migration.sh` - Migration verification

## Usage

### Direct Execution
Scripts can be run from their new locations:
```bash
~/projects/custom-tools/scripts/claude/claude_exit_routine.sh
```

### Via Symlinks
Critical scripts have symlinks in home directory:
```bash
~/claude_exit_routine.sh         # → scripts/claude/
~/sync_docs_to_obsidian.sh      # → scripts/obsidian/
~/setup_superclaude.sh           # → scripts/claude/
```

### Adding to PATH
Add to your `.bashrc` or `.zshrc`:
```bash
export PATH="$PATH:$HOME/projects/custom-tools/scripts/claude"
export PATH="$PATH:$HOME/projects/custom-tools/scripts/obsidian"
```

## Documentation

Related documentation has been moved to the `documentation/` directory:
- Session management guides
- Sync workflow documentation
- Setup instructions
- Implementation details

## Maintenance

### Adding New Scripts
1. Place in appropriate category directory
2. Update this index
3. Create symlink if frequently used
4. Add documentation if complex

### Version Control
All scripts are now under git version control in the custom-tools repository.

## Benefits of Organization

1. **Cleaner Home Directory** - No more script clutter
2. **Better Organization** - Scripts grouped by function
3. **Version Control** - All scripts in git repository
4. **Documentation** - Centralized documentation
5. **Maintainability** - Easier to update and manage

---
*Scripts migrated from home directory on August 15, 2025*
