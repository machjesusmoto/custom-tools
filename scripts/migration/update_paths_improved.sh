#!/bin/bash

# Enhanced Path Update Script for TrueNAS Migration
# Version: 2.0
# Author: System Migration Tool
# Date: 2025-08-08

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="/mnt/projects-truenasprod1"
readonly LOG_FILE="${PROJECT_ROOT}/migration_$(date +%Y%m%d_%H%M%S).log"
readonly DRY_RUN="${DRY_RUN:-false}"
readonly MAX_BACKUP_SIZE="10G"  # Maximum backup size before warning

# Statistics counters
declare -i files_processed=0
declare -i files_updated=0
declare -i files_skipped=0
declare -i errors_count=0

# Path replacement mappings
declare -A PATH_REPLACEMENTS=(
    # WSL paths
    ["/mnt/c/Users/admin"]="/mnt/projects-truenasprod1/projects"
    ["/home/dtaylor"]="/mnt/projects-truenasprod1"
    ["C:\\\\Users\\\\admin"]="/mnt/projects-truenasprod1/projects"
    ["C:/Users/admin"]="/mnt/projects-truenasprod1/projects"
    
    # GitHub specific paths
    ["/mnt/c/Users/admin/GitHub"]="/mnt/projects-truenasprod1/projects"
    ["/home/dtaylor/GitHub"]="/mnt/projects-truenasprod1/projects"
    ["C:\\\\Users\\\\admin\\\\GitHub"]="/mnt/projects-truenasprod1/projects"
    
    # Project-specific paths
    ["/home/dtaylor/GitHub/k8s-homelab-production"]="/mnt/projects-truenasprod1/projects/k8s-homelab-production"
    ["/mnt/c/Users/admin/GitHub/k8s-homelab-migration"]="/mnt/projects-truenasprod1/projects/k8s-homelab-production"
    
    # WSL-specific patterns
    ["wsl://Ubuntu"]="file:///mnt/projects-truenasprod1"
    ["wsl://"]="file:///mnt/projects-truenasprod1"
)

# Logging functions
log_info() {
    local message="$1"
    echo -e "${BLUE}[INFO]${NC} ${message}" | tee -a "$LOG_FILE"
}

log_success() {
    local message="$1"
    echo -e "${GREEN}[SUCCESS]${NC} ${message}" | tee -a "$LOG_FILE"
}

log_warning() {
    local message="$1"
    echo -e "${YELLOW}[WARNING]${NC} ${message}" | tee -a "$LOG_FILE"
}

log_error() {
    local message="$1"
    echo -e "${RED}[ERROR]${NC} ${message}" | tee -a "$LOG_FILE"
    ((errors_count++))
}

# Validation functions
validate_environment() {
    log_info "Validating environment..."
    
    # Check if running in correct directory
    if [[ ! -d "$PROJECT_ROOT" ]]; then
        log_error "Project root directory not found: $PROJECT_ROOT"
        exit 1
    fi
    
    # Check disk space for backup
    local available_space
    available_space=$(df -h "$PROJECT_ROOT" | awk 'NR==2 {print $4}')
    log_info "Available disk space: $available_space"
    
    # Check write permissions
    if [[ ! -w "$PROJECT_ROOT" ]]; then
        log_error "No write permission for: $PROJECT_ROOT"
        exit 1
    fi
    
    # Check required tools
    for tool in sed grep find; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "Required tool not found: $tool"
            exit 1
        fi
    done
    
    log_success "Environment validation complete"
}

# Backup creation with validation
create_backup() {
    local backup_dir="$PROJECT_ROOT/backup_$(date +%Y%m%d_%H%M%S)"
    
    log_info "Creating backup directory: $backup_dir"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create backup at: $backup_dir"
        echo "$backup_dir"
        return
    fi
    
    mkdir -p "$backup_dir"
    
    # Check backup size estimate
    local estimated_size
    estimated_size=$(du -sh "$PROJECT_ROOT" 2>/dev/null | cut -f1)
    log_info "Estimated backup size: $estimated_size"
    
    echo "$backup_dir"
}

# Progress indicator
show_progress() {
    local current=$1
    local total=$2
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    
    printf "\rProgress: ["
    printf "%${filled}s" | tr ' ' '='
    printf "%$((50 - filled))s" | tr ' ' '-'
    printf "] %d%% (%d/%d)" "$percent" "$current" "$total"
}

# Safe file update with validation
update_file() {
    local file="$1"
    local backup_dir="$2"
    local file_updated=false
    
    ((files_processed++))
    
    # Skip binary files
    if file -b --mime-type "$file" | grep -q "text/"; then
        :  # Text file, proceed
    else
        log_warning "Skipping binary file: $file"
        ((files_skipped++))
        return 1
    fi
    
    # Create backup
    if [[ "$DRY_RUN" == "false" ]]; then
        local backup_path="$backup_dir${file#$PROJECT_ROOT}"
        mkdir -p "$(dirname "$backup_path")"
        cp -p "$file" "$backup_path" 2>/dev/null || {
            log_error "Failed to backup: $file"
            return 1
        }
    fi
    
    # Create temporary file for updates
    local temp_file="${file}.tmp.$$"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        cp "$file" "$temp_file" 2>/dev/null || {
            log_error "Failed to create temp file for: $file"
            return 1
        }
    fi
    
    # Apply all replacements
    for old_path in "${!PATH_REPLACEMENTS[@]}"; do
        new_path="${PATH_REPLACEMENTS[$old_path]}"
        
        if grep -qF "$old_path" "$file" 2>/dev/null; then
            if [[ "$DRY_RUN" == "true" ]]; then
                log_info "[DRY RUN] Would replace in $file: $old_path -> $new_path"
                file_updated=true
            else
                sed -i "s|$old_path|$new_path|g" "$temp_file" 2>/dev/null || {
                    log_error "Failed to update: $file"
                    rm -f "$temp_file"
                    return 1
                }
                file_updated=true
            fi
        fi
    done
    
    # If file was updated, replace the original
    if [[ "$file_updated" == "true" ]]; then
        if [[ "$DRY_RUN" == "false" ]]; then
            mv "$temp_file" "$file" 2>/dev/null || {
                log_error "Failed to replace: $file"
                rm -f "$temp_file"
                return 1
            }
        fi
        ((files_updated++))
        return 0
    else
        [[ "$DRY_RUN" == "false" ]] && rm -f "$temp_file"
        ((files_skipped++))
        return 1
    fi
}

# Process files by type
process_files() {
    local file_pattern="$1"
    local file_type="$2"
    local backup_dir="$3"
    
    log_info "Processing $file_type files..."
    
    # Count total files
    local total_files
    total_files=$(find "$PROJECT_ROOT" -type f -name "$file_pattern" 2>/dev/null | wc -l)
    
    if [[ $total_files -eq 0 ]]; then
        log_warning "No $file_type files found"
        return
    fi
    
    log_info "Found $total_files $file_type files"
    
    local current=0
    
    while IFS= read -r file; do
        ((current++))
        show_progress "$current" "$total_files"
        
        if update_file "$file" "$backup_dir"; then
            log_success "✓ Updated: ${file#$PROJECT_ROOT/}"
        fi
    done < <(find "$PROJECT_ROOT" -type f -name "$file_pattern" 2>/dev/null)
    
    echo  # New line after progress bar
}

# Verification function
verify_updates() {
    log_info "Verifying updates..."
    
    local remaining_old_paths=0
    
    for old_path in "${!PATH_REPLACEMENTS[@]}"; do
        local count
        count=$(grep -r "$old_path" "$PROJECT_ROOT" \
            --include="*.json" --include="*.md" 2>/dev/null | wc -l)
        
        if [[ $count -gt 0 ]]; then
            log_warning "Found $count remaining instances of: $old_path"
            ((remaining_old_paths += count))
        fi
    done
    
    if [[ $remaining_old_paths -eq 0 ]]; then
        log_success "All paths successfully updated!"
    else
        log_warning "Total remaining old paths: $remaining_old_paths"
    fi
}

# Cleanup function
cleanup() {
    log_info "Cleaning up temporary files..."
    find "$PROJECT_ROOT" -name "*.tmp.$$" -delete 2>/dev/null
    log_success "Cleanup complete"
}

# Main execution
main() {
    echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}    TrueNAS Path Migration Tool v2.0${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
    echo
    
    # Parse arguments
    if [[ "${1:-}" == "--dry-run" ]]; then
        DRY_RUN=true
        log_warning "DRY RUN MODE - No files will be modified"
    fi
    
    # Setup log file
    log_info "Starting migration process at $(date)"
    log_info "Log file: $LOG_FILE"
    
    # Validate environment
    validate_environment
    
    # Create backup
    BACKUP_DIR=$(create_backup)
    log_success "Backup directory: $BACKUP_DIR"
    
    # Process files
    process_files "*.json" "JSON" "$BACKUP_DIR"
    process_files "*.md" "Markdown" "$BACKUP_DIR"
    
    # Verify updates
    [[ "$DRY_RUN" == "false" ]] && verify_updates
    
    # Summary
    echo
    echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                 Migration Summary${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
    echo -e "Files processed:  ${BLUE}$files_processed${NC}"
    echo -e "Files updated:    ${GREEN}$files_updated${NC}"
    echo -e "Files skipped:    ${YELLOW}$files_skipped${NC}"
    echo -e "Errors:          ${RED}$errors_count${NC}"
    echo -e "Backup location:  ${BLUE}$BACKUP_DIR${NC}"
    echo -e "Log file:        ${BLUE}$LOG_FILE${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
    
    # Cleanup
    cleanup
    
    # Exit status
    if [[ $errors_count -gt 0 ]]; then
        log_error "Migration completed with $errors_count errors"
        exit 1
    else
        log_success "Migration completed successfully!"
        exit 0
    fi
}

# Trap for cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"