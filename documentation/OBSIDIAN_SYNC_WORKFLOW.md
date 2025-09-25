# Obsidian Documentation Sync Workflow
*Version: 1.0.0*
*Last Updated: August 15, 2025*
*Status: Active*

This document describes the automated workflow for synchronizing project documentation to your Obsidian knowledge base.

## Overview

The documentation sync workflow ensures all project documentation, environment configurations, and AI tool documentation are automatically mirrored to your Obsidian vault for centralized knowledge management.

## Architecture

```
Source Locations                    Obsidian Vault
┌─────────────────┐                ┌──────────────────────┐
│ ~/projects/     │───sync───────▶│ Documentation/       │
│                 │                │   Projects/          │
│                 │                │     active-projects/ │
└─────────────────┘                └──────────────────────┘
                                   
┌─────────────────┐                ┌──────────────────────┐
│ ~/ai-tools/     │───sync───────▶│ Documentation/       │
│                 │                │   Projects/          │
│                 │                │     ai-tools/        │
└─────────────────┘                └──────────────────────┘
                                   
┌─────────────────┐                ┌──────────────────────┐
│ ~/              │───sync───────▶│ Documentation/       │
│ Environment     │                │   Projects/          │
│ Docs            │                │     environment/     │
└─────────────────┘                └──────────────────────┘
```

## Sync Script Features

### Automated Discovery
- Scans all projects in `~/projects/`
- Discovers AI tools in `~/ai-tools/`
- Finds environment documentation in home directory
- Identifies SuperClaude Framework docs in `~/.claude/`

### Document Patterns Synced
```bash
# Markdown files
*.md, *.MD

# Standard documentation
README*, CHANGELOG*, TODO*, CONTRIBUTING*, LICENSE*

# Nested documentation
docs/*.md
.claude/*.md
```

### Exclusions
The sync automatically excludes:
- `node_modules/`
- `.git/`
- Build directories (`dist/`, `build/`, `target/`)
- Temporary files (`*.backup`, `*.tmp`)
- Coverage reports

## Usage

### Basic Sync Operation
```bash
# Run documentation sync
~/sync_docs_to_obsidian.sh

# Or explicitly
~/sync_docs_to_obsidian.sh sync
```

### View Sync Report
```bash
# Display last sync report
~/sync_docs_to_obsidian.sh report
```

### Clean Archive
```bash
# Remove old archived data
~/sync_docs_to_obsidian.sh clean
```

### Get Help
```bash
# Show usage information
~/sync_docs_to_obsidian.sh help
```

## Obsidian Vault Structure

After sync, your Obsidian vault will contain:

```
Obsidian/
├── Documentation/
│   └── Projects/
│       ├── active-projects/       # All ~/projects/ docs
│       │   ├── k8s-homelab-production/
│       │   ├── connectbot/
│       │   ├── custom-tools/
│       │   └── .../
│       ├── ai-tools/              # All ~/ai-tools/ docs
│       │   ├── AIShell/
│       │   ├── Fabric/
│       │   ├── serena/
│       │   └── .../
│       ├── environment/           # Environment docs
│       │   ├── CLAUDE.md
│       │   ├── STANDARDS_AND_GUIDELINES.md
│       │   ├── SuperClaude/       # Framework docs
│       │   └── .../
│       └── _sync_report.md        # Sync statistics
```

## Project Metadata

Each synced project includes a `_metadata.md` file with:
- Last sync timestamp
- Document count
- Source location
- Sync configuration

Example:
```markdown
# Project: k8s-homelab-production

*Last Synced: 2025-08-15 10:30:00*
*Documents: 12*

## Project Location
`/home/dtaylor/projects/k8s-homelab-production`
```

## Automation Options

### Manual Sync
Run the script manually when needed:
```bash
~/sync_docs_to_obsidian.sh
```

### Cron Job (Optional)
Add to crontab for automatic daily sync:
```bash
# Daily at 2 AM
0 2 * * * /home/dtaylor/sync_docs_to_obsidian.sh >> /home/dtaylor/.sync_docs.log 2>&1
```

### Git Hook (Optional)
Add to `.git/hooks/post-commit` in projects:
```bash
#!/bin/bash
# Sync docs after each commit
if [[ -f ~/sync_docs_to_obsidian.sh ]]; then
    ~/sync_docs_to_obsidian.sh >/dev/null 2>&1 &
fi
```

## Integration with Claude Sessions

### Auto-Compaction Workflow
When Claude reaches 80% context usage:
1. Session automatically exports to Obsidian
2. Documentation sync captures any new project docs
3. Knowledge base remains complete and searchable

### MCP Integration
The Obsidian MCP server can:
- Search synced documentation
- Create links between sessions and project docs
- Generate knowledge graphs
- Track documentation changes

## Performance Considerations

### Sync Performance
- Initial sync: 10-30 seconds (depends on project count)
- Incremental sync: 2-5 seconds
- Large projects (>100 docs): May take longer

### Storage Usage
- Average project docs: 50-500 KB
- Full environment sync: ~5-10 MB
- Obsidian indexes: Additional 10-20% overhead

## Troubleshooting

### Common Issues

**Obsidian vault not found**
```bash
# Check vault location
ls -la ~/Obsidian/

# Update script if different location
nano ~/sync_docs_to_obsidian.sh
# Edit: OBSIDIAN_VAULT="${HOME}/YourVaultPath"
```

**Permission denied**
```bash
# Ensure script is executable
chmod +x ~/sync_docs_to_obsidian.sh

# Check vault permissions
chmod -R u+rw ~/Obsidian/Documentation/
```

**Documents not syncing**
```bash
# Check log file
tail -f ~/.sync_docs.log

# Run with verbose output
bash -x ~/sync_docs_to_obsidian.sh
```

## Best Practices

### Documentation Organization
1. **Keep project docs in standard locations** (`README.md`, `docs/`)
2. **Use consistent naming** for easy discovery
3. **Include metadata** in documentation headers
4. **Version your docs** with timestamps or version numbers

### Sync Frequency
- **Daily**: For active development
- **Weekly**: For stable projects
- **On-demand**: For documentation updates
- **Post-commit**: For critical documentation

### Knowledge Management
1. **Review sync reports** regularly
2. **Link related documents** in Obsidian
3. **Tag synced content** for easy filtering
4. **Archive old versions** when major updates occur

## Security Considerations

### Sensitive Information
- Script excludes `.env` files by default
- API keys and secrets should never be in docs
- Review synced content periodically
- Use `.syncignore` files if needed (future feature)

### Access Control
- Obsidian vault should have appropriate permissions
- Sync script runs with user privileges only
- No network access required (local sync only)

## Future Enhancements

### Planned Features
1. **Bi-directional sync** - Edit in Obsidian, sync back
2. **Selective sync** - Choose specific projects
3. **Incremental updates** - Only sync changed files
4. **Sync profiles** - Different configs for different needs
5. **Web UI** - Visual sync management

### Integration Goals
- GitHub Actions integration
- Real-time file watching
- Conflict resolution
- Version history tracking

## Related Documentation

- [OBSIDIAN_MCP_SETUP.md](./OBSIDIAN_MCP_SETUP.md) - MCP server configuration
- [STANDARDS_AND_GUIDELINES.md](./STANDARDS_AND_GUIDELINES.md) - Documentation standards
- [DTAYLOR_ENVIRONMENT.md](./DTAYLOR_ENVIRONMENT.md) - Environment overview

---
*This workflow ensures comprehensive knowledge capture and organization across all development activities.*