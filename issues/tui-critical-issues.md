# TUI Critical Issues: Navigation, Selection, Path Dependencies, and Exit Problems

## Problem Summary
The Rust TUI for the backup system has several critical issues preventing normal usage. The application compiles successfully but has runtime problems with core functionality.

## Issues Identified

### 1. Path Dependency Problem
**Current Behavior:**
- TUI requires running from project directory
- Fails with "Failed to read config file: backup-config.json" when run from other locations
- Error: `No such file or directory (os error 2)`

**Expected Behavior:**
- Should be callable from anywhere
- Should locate config files regardless of current working directory
- Should check standard locations (~/.config/backup-manager/, installation directory, etc.)

### 2. Navigation Not Working
**Current Behavior:**
- Arrow keys do not move selection
- Vim keybindings (j/k) do not work
- No visual feedback for current selection position
- Unable to navigate through menu items

**Expected Behavior:**
- Arrow keys should move selection up/down
- j/k keys should provide vim-style navigation
- Current selection should be visually highlighted
- Tab should switch between sections

### 3. Selection/Deselection Not Functional
**Current Behavior:**
- Cannot toggle individual backup items
- Cannot select/deselect groups or categories
- Space bar does not toggle checkboxes
- Enter key does not activate selections
- No way to customize what gets backed up

**Expected Behavior:**
- Space bar should toggle item selection
- Should support group/category selection
- Visual indication of selected/deselected items
- Ability to select all/deselect all

### 4. Quit Function Broken
**Current Behavior:**
- Pressing 'Q' causes UI to go blank
- Application locks up instead of exiting
- Terminal not properly restored
- Requires force kill (Ctrl+C) to exit

**Expected Behavior:**
- 'Q' or 'q' should cleanly exit the application
- Terminal should be properly restored
- Cursor should be made visible again
- No cleanup artifacts left behind

## Technical Analysis

### Affected Components
- **Event Handling**: `src/core/app.rs` - Event loop not processing keyboard input correctly
- **Path Resolution**: `src/core/config.rs` - Config file path hardcoded to current directory
- **State Management**: `src/core/state.rs` - Selection state not updating
- **Terminal Management**: `src/ui/terminal.rs` - Cleanup/restoration issues
- **Main Loop**: `src/main.rs` - Exit condition not properly handled

### Root Causes (Preliminary)
1. Event polling might be using synchronous instead of async handling
2. KeyEvent matching might be case-sensitive or using wrong key codes
3. Config path resolution not using proper search paths
4. Terminal restore not being called on all exit paths
5. State mutations might not be triggering UI updates

## Environment
- OS: Arch Linux
- Terminal: (varies - tested in multiple terminals)
- Rust version: Latest stable
- Build: Release mode
- Commit: 819d5ad

## Reproduction Steps
1. Build project: `cargo build --release`
2. Run from home directory: `backup-ui`
3. Observe config file error
4. Run from project directory: `./target/release/backup-ui`
5. Try navigating with arrow keys or j/k - no movement
6. Try selecting items with space/enter - no effect
7. Press 'Q' to quit - UI blanks and locks

## Priority
**CRITICAL** - Application is unusable in current state

## Solution Implemented (2025-02-04)

### Fixes Applied

#### 1. Config File Path Resolution ✅
**File**: `src/core/config.rs`
- Added multi-location search in following order:
  1. Current directory
  2. `~/.config/backup-manager/`
  3. `/etc/backup-manager/`
  4. Executable directory
  5. Development paths
- Application now works from any directory

#### 2. Keyboard Navigation ✅
**Files**: `src/core/app.rs`, `src/ui/screens/main_menu.rs`, `src/ui/screens/backup_mode_selection.rs`
- Connected Menu widget to keyboard handlers
- Arrow keys (Up/Down) navigate menus
- Vim keys (j/k) provide alternative navigation
- Enter key selects menu items
- Visual highlighting shows current selection

#### 3. Selection/Deselection ✅
**File**: `src/ui/screens/backup_item_selection.rs`
- Space bar toggles item selection
- 'a' selects all items
- 'n' deselects all items
- Visual feedback with [✓] for selected items

#### 4. Exit Function ✅
**Files**: `src/main.rs`, `src/core/app.rs`
- Fixed 'q'/'Q' key handling to properly exit
- Added panic handler for terminal restoration
- Ensures terminal cleanup on all exit paths
- Cursor visibility restored

### Testing Completed
- [x] Build passes with warnings only
- [x] Config loads from any directory
- [x] Navigation works with arrows and vim keys
- [x] Selection toggles with space bar
- [x] Clean exit with 'q' or 'Q'
- [x] Terminal properly restored

---
*Issue created from testing session on 2025-02-04*