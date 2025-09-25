# Claude Exit Command Configuration
*Version: 1.0.0*
*Last Updated: August 15, 2025*
*Status: Ready for Implementation*

This document provides the configuration for creating a custom `/exit` or `/save` slash command in Claude.

## Slash Command Definition

### Command: `/exit` or `/save-session`

**Purpose**: Comprehensive session export and documentation sync before exit or compaction

**Triggers**:
- User types `/exit` 
- User types `/save-session`
- User types `/save`
- Context usage reaches 80%
- Before session compaction
- At natural session breakpoints

## Command Implementation

### For Claude to Execute

When the `/exit` command is triggered, Claude should:

1. **Generate Session Summary**
   - List major accomplishments
   - Document code changes
   - Note key decisions
   - Record continuation points

2. **Execute Exit Routine**
   ```bash
   ~/claude_exit_routine.sh exit
   ```

3. **Confirm Completion**
   - Display export location
   - Show sync statistics
   - Provide continuation instructions

### Command Response Template

```markdown
## 🔄 Session Exit Routine Initiated

### Exporting Session...
✅ Session summary generated
✅ Documentation synced to Obsidian
✅ Knowledge preserved at: `~/Obsidian/AI Sessions/Claude/YYYY-MM/`
✅ Continuation points documented

### Session Metrics
- Tasks Completed: [X]
- Files Modified: [Y]
- Documentation Created: [Z]
- Context Usage: [%]

### Next Session
To continue this work:
1. Reference: `[session-file-path]`
2. Review continuation points in export
3. Use `--resume` flag if available

### Ready for:
- ✅ Safe session closure
- ✅ Context compaction
- ✅ New session start

**Session successfully preserved!** 🎉
```

## Quick Command Variants

### `/save` - Quick Save
Quick export without full sync:
```bash
~/claude_exit_routine.sh quick
```

### `/sync` - Documentation Sync Only
Just sync docs to Obsidian:
```bash
~/claude_exit_routine.sh sync-only
```

### `/session-report` - View Last Report
Display previous exit report:
```bash
~/claude_exit_routine.sh report
```

## Integration with Claude Code

### Auto-Trigger Conditions

The exit routine should automatically trigger when:

1. **Context Usage > 80%**
   ```python
   if context_usage > 0.8:
       trigger_exit_routine()
   ```

2. **User Requests Compaction**
   ```
   User: "Please compact the context"
   Claude: [Runs /exit first, then compacts]
   ```

3. **Session Duration > 3 hours**
   ```python
   if session_duration > timedelta(hours=3):
       suggest_exit_routine()
   ```

4. **Major Milestone Completed**
   ```python
   if task.status == "major_complete":
       suggest_save_session()
   ```

## Command Memory/Storage

To save this as a permanent command, add to Claude's command registry:

### Command Definition Structure
```yaml
command: /exit
aliases: [/save-session, /save, /export]
description: "Export session and sync documentation before exit"
category: session-management
priority: high
auto_trigger:
  context_threshold: 0.8
  session_duration: 180  # minutes
  on_compaction: true
action:
  type: shell
  script: ~/claude_exit_routine.sh
  args: exit
  capture_output: true
  display_result: true
response:
  type: formatted
  template: session_exit_complete
  include_metrics: true
```

## Usage Examples

### Manual Trigger
```
User: /exit
Claude: [Executes exit routine and displays results]
```

### Before Compaction
```
User: "Let's compact the context"
Claude: "I'll first save our session to preserve all work..."
[Executes /exit]
Claude: "Session exported! Now proceeding with compaction..."
```

### At Natural Breakpoint
```
Claude: "We've completed the major implementation. Would you like me to save the session here?"
User: "Yes"
Claude: [Executes /exit]
```

### Quick Save
```
User: /save
Claude: [Executes quick export]
Claude: "Session quickly saved! Continue working..."
```

## Benefits

### For Users
1. **Never lose work** - Everything exported before compaction
2. **Easy resumption** - Clear continuation points
3. **Organized knowledge** - All docs in Obsidian
4. **One command** - Simple `/exit` handles everything

### For Claude
1. **Clean exits** - Proper session closure
2. **Context preservation** - Important details saved
3. **Reduced re-explanation** - Everything documented
4. **Better continuity** - Seamless session resumption

## Testing the Command

### Test Full Exit Routine
```bash
~/claude_exit_routine.sh exit
```

### Test Quick Export
```bash
~/claude_exit_routine.sh quick
```

### View Help
```bash
~/claude_exit_routine.sh help
```

## Customization Options

### Modify Export Location
Edit `OBSIDIAN_SESSIONS` in the script:
```bash
OBSIDIAN_SESSIONS="${OBSIDIAN_VAULT}/AI Sessions/Claude"
```

### Change Trigger Threshold
Edit context threshold for auto-trigger:
```bash
# Trigger at 75% instead of 80%
if context_usage > 0.75:
    trigger_exit_routine()
```

### Add Custom Metrics
Extend the metrics collection in the script:
```bash
# Add custom metrics
local custom_metric=$(your_command_here)
```

## Implementation Checklist

- [x] Exit routine script created
- [x] Script made executable
- [x] Documentation sync integrated
- [x] Session export format defined
- [x] Command structure documented
- [ ] Add to Claude command registry
- [ ] Test with actual session
- [ ] Configure auto-triggers
- [ ] Set up command aliases

## Related Files

- **Script**: `~/claude_exit_routine.sh`
- **Sync Tool**: `~/sync_docs_to_obsidian.sh`
- **Standards**: `~/STANDARDS_AND_GUIDELINES.md`
- **Environment**: `~/DTAYLOR_ENVIRONMENT.md`

---
*This command ensures comprehensive knowledge preservation before any session exit or compaction.*