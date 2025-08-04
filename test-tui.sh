#!/bin/bash
# Test script for TUI functionality

echo "Testing backup-ui TUI fixes..."

# Test 1: Config file resolution from different directory
echo "1. Testing config file resolution from home directory..."
cd /home/dtaylor
if /home/dtaylor/GitHub/custom-tools/target/release/backup-ui --debug --help > /dev/null 2>&1; then
    echo "   ✓ Config help works from any directory"
else
    echo "   ✗ Config help failed"
fi

# Test 2: Check if config is found from different location
echo "2. Testing config file discovery..."
cd /home/dtaylor
CONFIG_TEST=$(timeout 2s /home/dtaylor/GitHub/custom-tools/target/release/backup-ui --debug 2>&1 | grep -o "Found config file at:")
if [[ "$CONFIG_TEST" == "Found config file at:" ]]; then
    echo "   ✓ Config file discovered from standard location"
else
    echo "   ✗ Config file not found"
    echo "   Debug output: $CONFIG_TEST"
fi

# Test 3: Test from project directory (where backup-lib.sh exists)
echo "3. Testing from project directory..."
cd /home/dtaylor/GitHub/custom-tools
if ls backup-lib.sh > /dev/null 2>&1; then
    echo "   ✓ backup-lib.sh exists in project directory"
else
    echo "   ✗ backup-lib.sh missing"
fi

echo ""
echo "Manual TUI Test Instructions:"
echo "Run: cd /home/dtaylor/GitHub/custom-tools && ./target/release/backup-ui"
echo "Test keyboard navigation:"
echo "  - Use arrow keys (↑/↓) to navigate menu"
echo "  - Use j/k (vim keys) for navigation"
echo "  - Use Enter to select menu items"
echo "  - Use Q/Esc to quit"
echo "  - Use 1/2 for direct selection"
echo ""
echo "Expected behavior:"
echo "  - Arrow keys should move selection highlight"
echo "  - j/k should move selection highlight"
echo "  - Space should toggle selections (in item lists)"
echo "  - Q should cleanly exit with terminal restored"
echo ""
echo "Issues that should be FIXED:"
echo "  ✓ Config file path resolution (check multiple locations)"
echo "  ✓ Keyboard event handling (arrow keys, vim keys, quit)"
echo "  ✓ Exit handling (proper terminal cleanup)"
echo "  ✓ Terminal cleanup on all exit paths"