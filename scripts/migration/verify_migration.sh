#!/bin/bash

# Migration Verification Script
# Version: 1.0
# Purpose: Verify the completeness and integrity of the TrueNAS migration

set -euo pipefail

# Color codes
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Configuration
readonly PROJECT_ROOT="/mnt/projects-truenasprod1"
readonly REPORT_FILE="${PROJECT_ROOT}/migration_verification_$(date +%Y%m%d_%H%M%S).txt"

# Counters
declare -i total_checks=0
declare -i passed_checks=0
declare -i failed_checks=0
declare -i warnings=0

# Old path patterns to check
readonly -a OLD_PATHS=(
    "/mnt/c/Users/admin"
    "/home/dtaylor"
    "C:\\\\Users\\\\admin"
    "C:/Users/admin"
    "wsl://"
)

# Critical directories that should exist
readonly -a CRITICAL_DIRS=(
    "${PROJECT_ROOT}/.claude"
    "${PROJECT_ROOT}/projects"
    "${PROJECT_ROOT}/tools"
)

# Critical files that should exist
readonly -a CRITICAL_FILES=(
    "${PROJECT_ROOT}/.claude.json"
    "${PROJECT_ROOT}/.claude/CLAUDE.md"
    "${PROJECT_ROOT}/.claude/settings.json"
)

# Output functions
print_header() {
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}         Migration Verification Report${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo
}

check_pass() {
    local message="$1"
    echo -e "${GREEN}✓${NC} $message" | tee -a "$REPORT_FILE"
    ((passed_checks++))
    ((total_checks++))
}

check_fail() {
    local message="$1"
    echo -e "${RED}✗${NC} $message" | tee -a "$REPORT_FILE"
    ((failed_checks++))
    ((total_checks++))
}

check_warn() {
    local message="$1"
    echo -e "${YELLOW}⚠${NC} $message" | tee -a "$REPORT_FILE"
    ((warnings++))
}

section_header() {
    local title="$1"
    echo | tee -a "$REPORT_FILE"
    echo -e "${BLUE}--- $title ---${NC}" | tee -a "$REPORT_FILE"
}

# Verification functions
verify_directory_structure() {
    section_header "Directory Structure"
    
    for dir in "${CRITICAL_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            check_pass "Directory exists: ${dir#$PROJECT_ROOT/}"
        else
            check_fail "Directory missing: ${dir#$PROJECT_ROOT/}"
        fi
    done
}

verify_critical_files() {
    section_header "Critical Files"
    
    for file in "${CRITICAL_FILES[@]}"; do
        if [[ -f "$file" ]]; then
            check_pass "File exists: ${file#$PROJECT_ROOT/}"
            
            # Check if file is readable
            if [[ -r "$file" ]]; then
                check_pass "File is readable: ${file#$PROJECT_ROOT/}"
            else
                check_warn "File exists but not readable: ${file#$PROJECT_ROOT/}"
            fi
        else
            check_fail "File missing: ${file#$PROJECT_ROOT/}"
        fi
    done
}

verify_old_paths_removed() {
    section_header "Old Path Removal"
    
    for old_path in "${OLD_PATHS[@]}"; do
        local count_json count_md
        
        # Check JSON files
        count_json=$(grep -r "$old_path" "$PROJECT_ROOT" --include="*.json" 2>/dev/null | wc -l || echo 0)
        
        # Check MD files
        count_md=$(grep -r "$old_path" "$PROJECT_ROOT" --include="*.md" 2>/dev/null | wc -l || echo 0)
        
        local total_count=$((count_json + count_md))
        
        if [[ $total_count -eq 0 ]]; then
            check_pass "No instances of old path: $old_path"
        else
            # Check for false positives (like in documentation)
            local actual_paths
            actual_paths=$(grep -r "$old_path" "$PROJECT_ROOT" \
                --include="*.json" --include="*.md" 2>/dev/null | \
                grep -v "Email" | grep -v "identifying" | grep -v "old_path" | \
                wc -l || echo 0)
            
            if [[ $actual_paths -eq 0 ]]; then
                check_pass "Old path removed (ignoring false positives): $old_path"
            else
                check_fail "Found $actual_paths instances of old path: $old_path"
                check_warn "Run: grep -r '$old_path' $PROJECT_ROOT --include='*.json' --include='*.md'"
            fi
        fi
    done
}

verify_file_permissions() {
    section_header "File Permissions"
    
    # Check if files are writable by user
    local readonly_files
    readonly_files=$(find "$PROJECT_ROOT" -type f \( -name "*.json" -o -name "*.md" \) \
        ! -writable 2>/dev/null | wc -l)
    
    if [[ $readonly_files -eq 0 ]]; then
        check_pass "All JSON/MD files are writable"
    else
        check_warn "Found $readonly_files read-only JSON/MD files"
    fi
    
    # Check directory permissions
    local readonly_dirs
    readonly_dirs=$(find "$PROJECT_ROOT" -type d ! -writable 2>/dev/null | wc -l)
    
    if [[ $readonly_dirs -eq 0 ]]; then
        check_pass "All directories are writable"
    else
        check_warn "Found $readonly_dirs read-only directories"
    fi
}

verify_json_validity() {
    section_header "JSON File Validity"
    
    local invalid_json_count=0
    local json_files
    json_files=$(find "$PROJECT_ROOT" -name "*.json" -type f 2>/dev/null | head -20)
    
    while IFS= read -r json_file; do
        if python3 -m json.tool "$json_file" > /dev/null 2>&1; then
            :  # Valid JSON
        else
            check_fail "Invalid JSON: ${json_file#$PROJECT_ROOT/}"
            ((invalid_json_count++))
        fi
    done <<< "$json_files"
    
    if [[ $invalid_json_count -eq 0 ]]; then
        check_pass "Sample JSON files are valid"
    fi
}

verify_backup_exists() {
    section_header "Backup Verification"
    
    local backup_dirs
    backup_dirs=$(find "$PROJECT_ROOT" -maxdepth 1 -type d -name "backup_*" 2>/dev/null | wc -l)
    
    if [[ $backup_dirs -gt 0 ]]; then
        check_pass "Found $backup_dirs backup directories"
        
        # List backup directories
        find "$PROJECT_ROOT" -maxdepth 1 -type d -name "backup_*" 2>/dev/null | \
        while read -r backup_dir; do
            local size
            size=$(du -sh "$backup_dir" 2>/dev/null | cut -f1)
            check_pass "Backup: ${backup_dir#$PROJECT_ROOT/} (Size: $size)"
        done
    else
        check_warn "No backup directories found"
    fi
}

verify_claude_config() {
    section_header "Claude Configuration"
    
    # Check main Claude config
    if [[ -f "${PROJECT_ROOT}/.claude.json" ]]; then
        # Check if it contains the new paths
        if grep -q "/mnt/projects-truenasprod1" "${PROJECT_ROOT}/.claude.json" 2>/dev/null; then
            check_pass "Claude config contains new paths"
        else
            check_fail "Claude config missing new paths"
        fi
    else
        check_fail "Claude config file not found"
    fi
    
    # Check agent files
    local agent_count
    agent_count=$(find "${PROJECT_ROOT}/.claude/agents" -name "*.md" -type f 2>/dev/null | wc -l)
    
    if [[ $agent_count -gt 0 ]]; then
        check_pass "Found $agent_count agent configuration files"
    else
        check_warn "No agent configuration files found"
    fi
}

generate_summary() {
    section_header "Summary"
    
    local status="SUCCESS"
    [[ $failed_checks -gt 0 ]] && status="FAILED"
    [[ $warnings -gt 5 ]] && status="WARNING"
    
    echo | tee -a "$REPORT_FILE"
    echo "═══════════════════════════════════════" | tee -a "$REPORT_FILE"
    echo "Total Checks:    $total_checks" | tee -a "$REPORT_FILE"
    echo -e "Passed:          ${GREEN}$passed_checks${NC}" | tee -a "$REPORT_FILE"
    echo -e "Failed:          ${RED}$failed_checks${NC}" | tee -a "$REPORT_FILE"
    echo -e "Warnings:        ${YELLOW}$warnings${NC}" | tee -a "$REPORT_FILE"
    echo "═══════════════════════════════════════" | tee -a "$REPORT_FILE"
    
    if [[ "$status" == "SUCCESS" ]]; then
        echo -e "${GREEN}✓ Migration verification PASSED${NC}" | tee -a "$REPORT_FILE"
    elif [[ "$status" == "WARNING" ]]; then
        echo -e "${YELLOW}⚠ Migration completed with warnings${NC}" | tee -a "$REPORT_FILE"
    else
        echo -e "${RED}✗ Migration verification FAILED${NC}" | tee -a "$REPORT_FILE"
    fi
    
    echo | tee -a "$REPORT_FILE"
    echo "Full report saved to: $REPORT_FILE" | tee -a "$REPORT_FILE"
}

# Main execution
main() {
    print_header
    
    echo "Starting verification at $(date)" | tee -a "$REPORT_FILE"
    echo "Project root: $PROJECT_ROOT" | tee -a "$REPORT_FILE"
    
    verify_directory_structure
    verify_critical_files
    verify_old_paths_removed
    verify_file_permissions
    verify_json_validity
    verify_backup_exists
    verify_claude_config
    
    generate_summary
    
    # Exit code based on results
    [[ $failed_checks -eq 0 ]] && exit 0 || exit 1
}

main "$@"