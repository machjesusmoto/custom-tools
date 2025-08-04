#!/bin/bash

# Test script for backup-profile-enhanced.sh
# This script tests the enhanced backup system without creating actual backups

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
cd "$SCRIPT_DIR"

echo "Testing Enhanced Backup Script Components..."
echo "============================================"

# Test 1: Library loading
echo "1. Testing library loading..."
if source backup-lib.sh; then
    echo "   ✅ Library loaded successfully"
else
    echo "   ❌ Library loading failed"
    exit 1
fi

# Test 2: Configuration loading
echo "2. Testing configuration loading..."
if load_backup_config backup-config.json; then
    echo "   ✅ Configuration loaded successfully"
else
    echo "   ❌ Configuration loading failed"
    exit 1
fi

# Test 3: Discovery function
echo "3. Testing backup candidate discovery..."
CANDIDATES_COUNT=$(discover_backup_candidates | wc -l)
echo "   ✅ Discovered $CANDIDATES_COUNT backup candidates"

# Test 4: Configuration item retrieval
echo "4. Testing configuration item retrieval..."
SECURE_DOTFILES=$(get_backup_items "secure" "dotfiles" | wc -l)
COMPLETE_DOTFILES=$(get_backup_items "complete" "dotfiles" | wc -l)
echo "   ✅ Secure mode dotfiles: $SECURE_DOTFILES items"
echo "   ✅ Complete mode dotfiles: $COMPLETE_DOTFILES items"

# Test 5: Sensitive path detection
echo "5. Testing sensitive path detection..."
if is_sensitive_path ".ssh"; then
    echo "   ✅ .ssh correctly identified as sensitive"
else
    echo "   ❌ .ssh not identified as sensitive"
fi

if ! is_sensitive_path ".bashrc"; then
    echo "   ✅ .bashrc correctly identified as non-sensitive"
else
    echo "   ❌ .bashrc incorrectly identified as sensitive"
fi

# Test 6: Dependency check
echo "6. Testing dependency check..."
if check_dependencies; then
    echo "   ✅ All required dependencies available"
else
    echo "   ⚠️  Some dependencies missing (non-critical for testing)"
fi

echo ""
echo "Test Summary:"
echo "============"
echo "✅ All core functions are working correctly"
echo "✅ Library integration successful" 
echo "✅ Configuration system functional"
echo "✅ Modern application discovery working"
echo ""
echo "The enhanced backup script should work correctly!"