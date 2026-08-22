#!/bin/bash

# Script to update remaining paths in .claude directory
echo "Starting .claude directory path update..."

# More comprehensive path replacements
declare -A PATH_REPLACEMENTS=(
    # WSL paths
    ["/mnt/c/Users/admin"]="/mnt/projects-truenasprod1/projects"
    ["/home/dtaylor"]="/mnt/projects-truenasprod1"
    ["C:\\\\\\\\Users\\\\\\\\admin"]="/mnt/projects-truenasprod1/projects"
    ["C:/Users/admin"]="/mnt/projects-truenasprod1/projects"
    
    # GitHub specific paths
    ["/mnt/c/Users/admin/GitHub"]="/mnt/projects-truenasprod1/projects"
    ["/home/dtaylor/GitHub"]="/mnt/projects-truenasprod1/projects"
    ["C:\\\\\\\\Users\\\\\\\\admin\\\\\\\\GitHub"]="/mnt/projects-truenasprod1/projects"
    
    # Project-specific paths
    ["/home/dtaylor/GitHub/k8s-homelab-production"]="/mnt/projects-truenasprod1/projects/k8s-homelab-production"
    ["/mnt/c/Users/admin/GitHub/k8s-homelab-migration"]="/mnt/projects-truenasprod1/projects/k8s-homelab-production"
    
    # WSL-specific patterns
    ["wsl://Ubuntu"]="file:///mnt/projects-truenasprod1"
    ["wsl://"]="file:///mnt/projects-truenasprod1"
)

# Backup directory
BACKUP_DIR="/mnt/projects-truenasprod1/backup_claude_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "Created backup directory: $BACKUP_DIR"

# Counter for statistics
updated_count=0
total_count=0

# Process all JSON files in .claude directory
echo -e "\n=== Processing JSON files in .claude ==="
while IFS= read -r file; do
    ((total_count++))
    echo "Checking: $file"
    
    # Create backup
    backup_path="$BACKUP_DIR${file#/mnt/projects-truenasprod1}"
    mkdir -p "$(dirname "$backup_path")"
    cp "$file" "$backup_path"
    
    file_updated=false
    
    # Apply all replacements using sed
    for old_path in "${!PATH_REPLACEMENTS[@]}"; do
        new_path="${PATH_REPLACEMENTS[$old_path]}"
        
        # Check if the file contains the old path
        if grep -qF "$old_path" "$file" 2>/dev/null; then
            # Use sed with proper escaping for JSON files
            sed -i "s|$old_path|$new_path|g" "$file"
            file_updated=true
            echo "  Replaced: $old_path -> $new_path"
        fi
    done
    
    if [ "$file_updated" = true ]; then
        ((updated_count++))
        echo "✓ Updated: $file"
    fi
done < <(find /mnt/projects-truenasprod1/.claude -type f -name "*.json" 2>/dev/null)

json_updated=$updated_count
json_total=$total_count

# Reset counters
updated_count=0
total_count=0

# Process all MD files in .claude directory
echo -e "\n=== Processing Markdown files in .claude ==="
while IFS= read -r file; do
    ((total_count++))
    echo "Checking: $file"
    
    # Create backup
    backup_path="$BACKUP_DIR${file#/mnt/projects-truenasprod1}"
    mkdir -p "$(dirname "$backup_path")"
    cp "$file" "$backup_path"
    
    file_updated=false
    
    # Apply all replacements
    for old_path in "${!PATH_REPLACEMENTS[@]}"; do
        new_path="${PATH_REPLACEMENTS[$old_path]}"
        
        if grep -qF "$old_path" "$file" 2>/dev/null; then
            sed -i "s|$old_path|$new_path|g" "$file"
            file_updated=true
            echo "  Replaced: $old_path -> $new_path"
        fi
    done
    
    if [ "$file_updated" = true ]; then
        ((updated_count++))
        echo "✓ Updated: $file"
    fi
done < <(find /mnt/projects-truenasprod1/.claude -type f -name "*.md" 2>/dev/null)

md_updated=$updated_count
md_total=$total_count

# Also check and rename directories with old paths in their names
echo -e "\n=== Checking for directories with old paths in names ==="
if [ -d "/mnt/projects-truenasprod1/.claude/projects/-home-dtaylor-GitHub-k8s-homelab-production" ]; then
    echo "Found directory with old path in name. Renaming..."
    mv "/mnt/projects-truenasprod1/.claude/projects/-home-dtaylor-GitHub-k8s-homelab-production" \
       "/mnt/projects-truenasprod1/.claude/projects/k8s-homelab-production" 2>/dev/null || \
       echo "Directory rename may have failed or already exists"
fi

# Summary
echo -e "\n=== Update Summary for .claude directory ==="
echo "JSON files: Updated $json_updated out of $json_total files"
echo "Markdown files: Updated $md_updated out of $md_total files"
echo "Total: Updated $((json_updated + md_updated)) out of $((json_total + md_total)) files"
echo "Backup location: $BACKUP_DIR"
echo -e "\nPath update for .claude directory completed!"