#!/bin/bash

# Script to update old paths in JSON and MD files after migration
# This script updates paths from WSL/Windows to the new TrueNAS location

echo "Starting path update process..."

# Common path replacements
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
    
    # Common project paths
    ["/home/dtaylor/GitHub/k8s-homelab-production"]="/mnt/projects-truenasprod1/projects/k8s-homelab-production"
    ["/mnt/c/Users/admin/GitHub/k8s-homelab-migration"]="/mnt/projects-truenasprod1/projects/k8s-homelab-production"
)

# Backup directory
BACKUP_DIR="/mnt/projects-truenasprod1/backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "Created backup directory: $BACKUP_DIR"

# Function to update a single file
update_file() {
    local file="$1"
    local file_updated=false
    
    # Create backup
    local backup_path="$BACKUP_DIR${file#/mnt/projects-truenasprod1}"
    mkdir -p "$(dirname "$backup_path")"
    cp "$file" "$backup_path"
    
    # Create temporary file for updates
    local temp_file="${file}.tmp"
    cp "$file" "$temp_file"
    
    # Apply all replacements
    for old_path in "${!PATH_REPLACEMENTS[@]}"; do
        new_path="${PATH_REPLACEMENTS[$old_path]}"
        
        # Check if the file contains the old path
        if grep -q "$old_path" "$temp_file" 2>/dev/null; then
            # Use sed to replace paths
            sed -i "s|$old_path|$new_path|g" "$temp_file"
            file_updated=true
            echo "  Replaced: $old_path -> $new_path"
        fi
    done
    
    # If file was updated, replace the original
    if [ "$file_updated" = true ]; then
        mv "$temp_file" "$file"
        echo "✓ Updated: $file"
        return 0
    else
        rm "$temp_file"
        return 1
    fi
}

# Counter for statistics
updated_count=0
total_count=0

# Process JSON files
echo -e "\n=== Processing JSON files ==="
while IFS= read -r file; do
    ((total_count++))
    echo "Checking: $file"
    if update_file "$file"; then
        ((updated_count++))
    fi
done < <(find /mnt/projects-truenasprod1 -type f -name "*.json" 2>/dev/null)

json_updated=$updated_count
json_total=$total_count

# Reset counters for MD files
updated_count=0
total_count=0

# Process MD files
echo -e "\n=== Processing Markdown files ==="
while IFS= read -r file; do
    ((total_count++))
    echo "Checking: $file"
    if update_file "$file"; then
        ((updated_count++))
    fi
done < <(find /mnt/projects-truenasprod1 -type f -name "*.md" 2>/dev/null)

md_updated=$updated_count
md_total=$total_count

# Summary
echo -e "\n=== Update Summary ==="
echo "JSON files: Updated $json_updated out of $json_total files"
echo "Markdown files: Updated $md_updated out of $md_total files"
echo "Total: Updated $((json_updated + md_updated)) out of $((json_total + md_total)) files"
echo "Backup location: $BACKUP_DIR"
echo -e "\nPath update process completed!"