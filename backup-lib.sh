#!/bin/bash

# Shared Backup Library
# Modular functions for backup operations with UI integration support
# Version: 1.0.0

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Global variables for library state
BACKUP_LIB_VERSION="1.0.0"
BACKUP_LOG_FD=""
BACKUP_PROGRESS_FD=""
BACKUP_CONFIG_LOADED=false

# ANSI color codes for consistent output
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# ===========================
# Core Logging Functions
# ===========================

# Initialize logging system
# Usage: log_init <log_file> [progress_fd]
log_init() {
    local log_file="$1"
    local progress_fd="${2:-""}"
    
    # Create log file with secure permissions
    touch "$log_file"
    chmod 600 "$log_file"
    
    # Initialize log file
    {
        echo "Backup Operation Log - $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Library Version: $BACKUP_LIB_VERSION"
        echo "========================================"
        echo ""
    } > "$log_file"
    
    BACKUP_LOG_FD="$log_file"
    BACKUP_PROGRESS_FD="$progress_fd"
}

# Log message to file and optionally to stdout
# Usage: log_message <level> <message>
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[$timestamp] [$level] $message"
    
    # Write to log file if initialized
    if [[ -n "$BACKUP_LOG_FD" ]]; then
        echo "$log_entry" >> "$BACKUP_LOG_FD"
    fi
    
    # Write to stdout based on level
    case "$level" in
        ERROR)
            echo -e "${RED}ERROR: $message${NC}" >&2
            ;;
        WARN)
            echo -e "${YELLOW}WARNING: $message${NC}" >&2
            ;;
        INFO)
            echo -e "${GREEN}INFO: $message${NC}"
            ;;
        DEBUG)
            if [[ "${BACKUP_DEBUG:-false}" == "true" ]]; then
                echo -e "${CYAN}DEBUG: $message${NC}"
            fi
            ;;
        *)
            echo "$message"
            ;;
    esac
}

# Progress reporting for UI integration
# Usage: report_progress <phase> <current> <total> [additional_data]
report_progress() {
    local phase="$1"
    local current="$2"
    local total="$3"
    local additional_data="${4:-{}}"
    
    if [[ -n "$BACKUP_PROGRESS_FD" ]]; then
        local percentage=$(( (current * 100) / total ))
        local progress_json="{\"phase\":\"$phase\",\"current\":$current,\"total\":$total,\"percentage\":$percentage,\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"data\":$additional_data}"
        echo "$progress_json" >&$BACKUP_PROGRESS_FD
    fi
    
    log_message "INFO" "Progress: $phase ($current/$total - ${percentage:-0}%)"
}

# ===========================
# Configuration Management
# ===========================

# Load backup configuration from JSON file
# Usage: load_backup_config <config_file>
load_backup_config() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        log_message "ERROR" "Configuration file not found: $config_file"
        return 1
    fi
    
    # Validate JSON format
    if ! command -v jq &>/dev/null; then
        log_message "WARN" "jq not available, skipping JSON validation"
    else
        if ! jq empty "$config_file" 2>/dev/null; then
            log_message "ERROR" "Invalid JSON in configuration file: $config_file"
            return 1
        fi
    fi
    
    export BACKUP_CONFIG_FILE="$config_file"
    BACKUP_CONFIG_LOADED=true
    log_message "INFO" "Configuration loaded from: $config_file"
    return 0
}

# Get backup items for specified mode
# Usage: get_backup_items <mode> [category]
get_backup_items() {
    local mode="$1"
    local category="${2:-all}"
    
    if [[ "$BACKUP_CONFIG_LOADED" != "true" ]]; then
        log_message "ERROR" "Configuration not loaded. Call load_backup_config first."
        return 1
    fi
    
    if command -v jq &>/dev/null; then
        local filter
        if [[ "$category" == "exclusions" ]]; then
            filter=".backup_modes.${mode}.exclusions"
        elif [[ "$category" == "all" ]]; then
            filter=".backup_modes.${mode}"
        else
            filter=".backup_modes.${mode}.categories.${category}"
        fi
        
        jq -r "${filter} | if type == \"array\" then .[] else . end" "$BACKUP_CONFIG_FILE" 2>/dev/null || {
            log_message "ERROR" "Failed to parse configuration for mode: $mode, category: $category"
            return 1
        }
    else
        log_message "ERROR" "jq required for configuration parsing"
        return 1
    fi
}

# ===========================
# System Discovery Functions
# ===========================

# Discover all backup candidates on the system
# Usage: discover_backup_candidates [--include-sizes]
discover_backup_candidates() {
    local include_sizes=false
    
    if [[ "${1:-}" == "--include-sizes" ]]; then
        include_sizes=true
    fi
    
    log_message "INFO" "Discovering backup candidates..."
    
    local candidates=()
    local categories=(
        "dotfiles:Shell configurations and dotfiles"
        "configs:Application configurations"
        "credentials:SSH, GPG, and authentication data"  
        "development:Development tools and configurations"
        "applications:Application data and settings"
        "documents:Personal documents and files"
        "system:System configurations and themes"
    )
    
    # Modern config directories to scan
    local config_dirs=(
        ".config"
        ".local/share"
        ".local/bin"
        ".var/app"  # Flatpak user data
    )
    
    # Claude/AI tools
    if [[ -d "$HOME/.config/claude" ]] || [[ -f "$HOME/.claude.json" ]]; then
        candidates+=("claude:AI assistant configurations:configs")
    fi
    
    # Modern editors
    local editors=("code" "cursor" "zed" "micro" "nvim")
    for editor in "${editors[@]}"; do
        if [[ -d "$HOME/.config/$editor" ]]; then
            candidates+=("$editor:$editor editor configuration:development")
        fi
    done
    
    # GitHub tools
    if [[ -d "$HOME/.config/gh" ]]; then
        candidates+=("gh:GitHub CLI configuration:development")
    fi
    if [[ -d "$HOME/.config/gh-copilot" ]]; then
        candidates+=("gh-copilot:GitHub Copilot CLI configuration:development")
    fi
    
    # Wayland/Hyprland ecosystem
    local wayland_tools=("hypr" "waybar" "rofi" "wofi" "wlogout" "swaylock" "swaync")
    for tool in "${wayland_tools[@]}"; do
        if [[ -d "$HOME/.config/$tool" ]]; then
            candidates+=("$tool:$tool Wayland configuration:system")
        fi
    done
    
    # Modern terminals
    local terminals=("ghostty" "alacritty" "kitty")
    for terminal in "${terminals[@]}"; do
        if [[ -d "$HOME/.config/$terminal" ]]; then
            candidates+=("$terminal:$terminal terminal configuration:applications")
        fi
    done
    
    # System monitoring tools
    local monitor_tools=("btop" "htop" "fastfetch")
    for tool in "${monitor_tools[@]}"; do
        if [[ -d "$HOME/.config/$tool" ]]; then
            candidates+=("$tool:$tool configuration:system")
        fi
    done
    
    # Starship prompt
    if [[ -f "$HOME/.config/starship.toml" ]]; then
        candidates+=("starship:Starship prompt configuration:system")
    fi
    
    # Modern applications
    local app_configs=(
        "1Password:1Password configuration:credentials"
        "BraveSoftware:Brave browser configuration:applications"
        "Termius:Termius SSH client configuration:applications"
        "Docker Desktop:Docker Desktop configuration:development"
    )
    
    for app_config in "${app_configs[@]}"; do
        IFS=':' read -r app desc category <<< "$app_config"
        if [[ -d "$HOME/.config/$app" ]]; then
            candidates+=("$app:$desc:$category")
        fi
    done
    
    # Qt theming
    local qt_tools=("Kvantum" "qt5ct" "qt6ct")
    for tool in "${qt_tools[@]}"; do
        if [[ -d "$HOME/.config/$tool" ]]; then
            candidates+=("$tool:$tool Qt theming:system")
        fi
    done
    
    # Systemd user services
    if [[ -d "$HOME/.config/systemd/user" ]]; then
        candidates+=("systemd-user:Systemd user services:system")
    fi
    
    # Traditional dotfiles
    local dotfiles=(".bashrc" ".zshrc" ".profile" ".gitconfig" ".vimrc" ".tmux.conf")
    for dotfile in "${dotfiles[@]}"; do
        if [[ -f "$HOME/$dotfile" ]]; then
            candidates+=("$(basename "$dotfile"):$(basename "$dotfile") configuration:dotfiles")
        fi
    done
    
    # Credentials directories
    local cred_dirs=(".ssh" ".gnupg" ".kube" ".aws")
    for dir in "${cred_dirs[@]}"; do
        if [[ -d "$HOME/$dir" ]]; then
            candidates+=("$dir:$(echo "$dir" | sed 's/^\.//') credentials:credentials")
        fi
    done
    
    # Output candidates
    for candidate in "${candidates[@]}"; do
        IFS=':' read -r name desc category <<< "$candidate"
        candidate_path="$HOME/.$name"
        [[ "$name" =~ ^\.?config ]] && candidate_path="$HOME/.config/${name#*.config/}"
        [[ "$name" =~ ^\.?local ]] && candidate_path="$HOME/.local/${name#*.local/}"
        
        if [[ "$include_sizes" == "true" ]]; then
            local size="0"
            if [[ -d "$candidate_path" ]]; then
                size=$(du -sb "$candidate_path" 2>/dev/null | cut -f1 || echo "0")
            elif [[ -f "$candidate_path" ]]; then
                size=$(stat -c%s "$candidate_path" 2>/dev/null || echo "0")
            fi
            echo "$name:$desc:$category:$size:$candidate_path"
        else
            echo "$name:$desc:$category:$candidate_path"
        fi
    done
}

# Check if path contains sensitive data
# Usage: is_sensitive_path <path>
is_sensitive_path() {
    local path="$1"
    local sensitive_patterns=(
        "\.ssh"
        "\.gnupg"
        "\.aws"
        "\.kube"
        "credentials"
        "\.password"
        "\.key"
        "\.pem"
        "\.p12"
        "\.keystore"
        "\.git-credentials"
        "\.docker/config\.json"
    )
    
    for pattern in "${sensitive_patterns[@]}"; do
        if [[ "$path" =~ $pattern ]]; then
            return 0
        fi
    done
    return 1
}

# ===========================
# Security Functions
# ===========================

# Set secure permissions on file or directory
# Usage: set_secure_permissions <path> [directory_mode] [file_mode]
set_secure_permissions() {
    local path="$1"
    local dir_mode="${2:-700}"
    local file_mode="${3:-600}"
    
    if [[ ! -e "$path" ]]; then
        log_message "WARN" "Path does not exist: $path"
        return 1
    fi
    
    if [[ -d "$path" ]]; then
        chmod "$dir_mode" "$path"
        find "$path" -type d -exec chmod "$dir_mode" {} \;
        find "$path" -type f -exec chmod "$file_mode" {} \;
        log_message "DEBUG" "Set directory permissions: $path ($dir_mode/$file_mode)"
    else
        chmod "$file_mode" "$path"
        log_message "DEBUG" "Set file permissions: $path ($file_mode)"
    fi
}

# Validate backup destination
# Usage: validate_backup_destination <path>
validate_backup_destination() {
    local dest_path="$1"
    local dest_dir=$(dirname "$dest_path")
    
    # Check if destination directory exists and is writable
    if [[ ! -d "$dest_dir" ]]; then
        log_message "ERROR" "Destination directory does not exist: $dest_dir"
        return 1
    fi
    
    if [[ ! -w "$dest_dir" ]]; then
        log_message "ERROR" "Destination directory is not writable: $dest_dir"
        return 1
    fi
    
    # Check available space (require at least 100MB)
    local available_space=$(df -B1 "$dest_dir" | awk 'NR==2 {print $4}')
    local required_space=$((100 * 1024 * 1024))  # 100MB
    
    if [[ "$available_space" -lt "$required_space" ]]; then
        log_message "ERROR" "Insufficient disk space. Available: $(numfmt --to=iec "$available_space"), Required: $(numfmt --to=iec "$required_space")"
        return 1
    fi
    
    log_message "INFO" "Backup destination validated: $dest_path"
    return 0
}

# Check for sensitive files and generate warnings
# Usage: check_sensitive_files <file_list>
check_sensitive_files() {
    local file_list="$1"
    local warnings=()
    
    while IFS= read -r file; do
        if is_sensitive_path "$file"; then
            warnings+=("$file")
            log_message "WARN" "Sensitive file detected: $file"
        fi
    done < "$file_list"
    
    if [[ ${#warnings[@]} -gt 0 ]]; then
        log_message "WARN" "Found ${#warnings[@]} sensitive files in backup selection"
        return 1
    fi
    
    return 0
}

# ===========================
# Archive Operations
# ===========================

# Create backup archive with progress reporting
# Usage: create_backup_archive <source_list> <output_file> <exclude_file>
create_backup_archive() {
    local source_list="$1"
    local output_file="$2"
    local exclude_file="${3:-}"
    
    log_message "INFO" "Creating backup archive: $output_file"
    
    # Count total files for progress reporting
    local total_files=0
    while IFS= read -r source; do
        if [[ -f "$source" ]]; then
            ((total_files++))
        elif [[ -d "$source" ]]; then
            total_files=$((total_files + $(find "$source" -type f 2>/dev/null | wc -l)))
        fi
    done < "$source_list"
    
    report_progress "archiving" 0 "$total_files" '{"total_files":'$total_files'}'
    
    # Build tar command
    local tar_cmd="tar -czf"
    local tar_args=("$output_file")
    
    # Add exclusions
    if [[ -n "$exclude_file" && -f "$exclude_file" ]]; then
        tar_args+=("--exclude-from=$exclude_file")
    fi
    
    # Common exclusions
    local common_exclusions=(
        "*.cache" "*Cache*" "*.log" "node_modules" "*.tmp"
        ".local/share/Trash" ".cache" ".npm/_cacache"
        ".cargo/registry/cache" ".yarn/cache"
    )
    
    for exclusion in "${common_exclusions[@]}"; do
        tar_args+=("--exclude=$exclusion")
    done
    
    # Add progress monitoring if available
    if command -v pv &>/dev/null; then
        tar_args+=("--checkpoint=100" "--checkpoint-action=exec=echo Progress: %u files")
    fi
    
    # Change to home directory for relative paths
    tar_args+=("-C" "$HOME")
    
    # Add sources
    while IFS= read -r source; do
        # Convert absolute paths to relative
        local rel_source="${source#$HOME/}"
        tar_args+=("$rel_source")
    done < "$source_list"
    
    # Execute tar command
    if "$tar_cmd" "${tar_args[@]}" 2>&1 | while IFS= read -r line; do
        log_message "DEBUG" "tar: $line"
        # Update progress if checkpoint messages detected
        if [[ "$line" =~ Progress:\ ([0-9]+)\ files ]]; then
            local current_files="${BASH_REMATCH[1]}"
            report_progress "archiving" "$current_files" "$total_files"
        fi
    done; then
        # Set secure permissions on archive
        set_secure_permissions "$output_file" "" "600"
        log_message "INFO" "Archive created successfully: $output_file"
        report_progress "archiving" "$total_files" "$total_files" '{"status":"completed"}'
        return 0
    else
        log_message "ERROR" "Failed to create archive: $output_file"
        return 1
    fi
}

# Calculate and verify archive hash
# Usage: calculate_archive_hash <archive_file> [hash_file]
calculate_archive_hash() {
    local archive_file="$1"
    local hash_file="${2:-${archive_file}.sha256}"
    
    if [[ ! -f "$archive_file" ]]; then
        log_message "ERROR" "Archive file not found: $archive_file"
        return 1
    fi
    
    log_message "INFO" "Calculating SHA256 hash for: $archive_file"
    report_progress "hashing" 0 1 '{"operation":"calculating"}'
    
    local hash=$(sha256sum "$archive_file" | cut -d' ' -f1)
    if [[ -n "$hash" ]]; then
        echo "$hash  $(basename "$archive_file")" > "$hash_file"
        set_secure_permissions "$hash_file" "" "600"
        log_message "INFO" "Hash calculated: $hash"
        report_progress "hashing" 1 1 '{"hash":"'$hash'","status":"completed"}'
        echo "$hash"
        return 0
    else
        log_message "ERROR" "Failed to calculate hash for: $archive_file"
        return 1
    fi
}

# Encrypt archive with GPG
# Usage: encrypt_archive <archive_file> [password_file]
encrypt_archive() {
    local archive_file="$1"
    local password_file="${2:-}"
    
    if [[ ! -f "$archive_file" ]]; then
        log_message "ERROR" "Archive file not found: $archive_file"
        return 1
    fi
    
    log_message "INFO" "Encrypting archive: $archive_file"
    report_progress "encryption" 0 1 '{"operation":"encrypting"}'
    
    local gpg_args=(
        "--symmetric"
        "--cipher-algo" "AES256"
        "--compress-algo" "2"
        "--s2k-count" "65011712"
        "--quiet"
        "--no-symkey-cache"
    )
    
    # Use password file if provided
    if [[ -n "$password_file" && -f "$password_file" ]]; then
        gpg_args+=("--batch" "--passphrase-file" "$password_file")
    fi
    
    gpg_args+=("$archive_file")
    
    if gpg "${gpg_args[@]}"; then
        # Remove unencrypted version securely
        shred -vuz "$archive_file" 2>/dev/null || rm -f "$archive_file"
        log_message "INFO" "Archive encrypted successfully: ${archive_file}.gpg"
        report_progress "encryption" 1 1 '{"status":"completed"}'
        return 0
    else
        log_message "ERROR" "Failed to encrypt archive: $archive_file"
        return 1
    fi
}

# ===========================
# Software Inventory Functions
# ===========================

# Generate comprehensive software inventory
# Usage: generate_software_inventory <output_file>
generate_software_inventory() {
    local output_file="$1"
    
    log_message "INFO" "Generating software inventory: $output_file"
    
    {
        echo "# Software Inventory - $(date '+%Y-%m-%d %H:%M:%S')"
        echo "# Generated by backup-lib.sh v$BACKUP_LIB_VERSION"
        echo ""
        
        echo "## System Information"
        echo "- OS: $(lsb_release -d 2>/dev/null | cut -f2 || uname -s)"
        echo "- Kernel: $(uname -r)"
        echo "- Architecture: $(uname -m)"
        echo "- Hostname: $(hostname)"
        echo ""
        
        echo "## System Packages (pacman)"
        echo '```'
        if command -v pacman &>/dev/null; then
            pacman -Qqe 2>/dev/null || echo "pacman not available"
        else
            echo "pacman not available"
        fi
        echo '```'
        echo ""
        
        echo "## AUR Packages"
        echo '```'
        if command -v pacman &>/dev/null; then
            pacman -Qqm 2>/dev/null || echo "No AUR packages"
        else
            echo "pacman not available"
        fi
        echo '```'
        echo ""
        
        if command -v flatpak &>/dev/null; then
            echo "## Flatpak Applications"
            echo '```'
            flatpak list --app --columns=application 2>/dev/null || echo "No Flatpak applications"
            echo '```'
            echo ""
        fi
        
        if command -v snap &>/dev/null; then
            echo "## Snap Packages"
            echo '```'
            snap list 2>/dev/null || echo "No snap packages"
            echo '```'
            echo ""
        fi
        
        echo "## Development Tools"
        echo ""
        
        if [[ -d "$HOME/.cargo/bin" ]]; then
            echo "### Rust/Cargo Tools"
            echo '```'
            ls -1 "$HOME/.cargo/bin" 2>/dev/null | grep -v "^cargo$\|^rustc$\|^rustup$" || echo "No cargo tools"
            echo '```'
            echo ""
        fi
        
        if command -v npm &>/dev/null; then
            echo "### Global NPM Packages"
            echo '```'
            npm list -g --depth=0 2>/dev/null | grep -v "npm@" | tail -n +2 | sed 's/[├─└]//g' | sed 's/^ *//' || echo "No global npm packages"
            echo '```'
            echo ""
        fi
        
        if command -v pip &>/dev/null; then
            echo "### Python Packages (user)"
            echo '```'
            pip list --user --format=freeze 2>/dev/null || echo "No user pip packages"
            echo '```'
            echo ""
        fi
        
        if command -v go &>/dev/null; then
            echo "### Go Tools"
            echo '```'
            ls -1 "$(go env GOPATH)/bin" 2>/dev/null || echo "No Go tools"
            echo '```'
            echo ""
        fi
        
        echo "## Custom Scripts and Binaries"
        echo "Tools found in .local/bin and .config/*/bin:"
        echo '```'
        find ~/.local/bin ~/.config/*/bin -type f -executable 2>/dev/null | sed "s|$HOME/||" | sort || echo "No custom binaries"
        echo '```'
        echo ""
        
        echo "## Shell Configuration"
        echo "Active shells and configurations:"
        echo '```'
        echo "Current shell: $SHELL"
        [[ -f ~/.bashrc ]] && echo "bash: ~/.bashrc exists"
        [[ -f ~/.zshrc ]] && echo "zsh: ~/.zshrc exists"
        [[ -f ~/.config/fish/config.fish ]] && echo "fish: ~/.config/fish/config.fish exists"
        echo '```'
        echo ""
        
        echo "## Desktop Environment / Window Manager"
        echo '```'
        echo "XDG_CURRENT_DESKTOP: ${XDG_CURRENT_DESKTOP:-not set}"
        echo "DESKTOP_SESSION: ${DESKTOP_SESSION:-not set}"
        echo "Wayland: $(if [[ -n "$WAYLAND_DISPLAY" ]]; then echo "yes ($WAYLAND_DISPLAY)"; else echo "no"; fi)"
        echo "X11: $(if [[ -n "$DISPLAY" ]]; then echo "yes ($DISPLAY)"; else echo "no"; fi)"
        echo '```'
        
        echo ""
        echo "---"
        echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        
    } > "$output_file"
    
    set_secure_permissions "$output_file" "" "600"
    log_message "INFO" "Software inventory generated: $output_file"
}

# ===========================
# Utility Functions
# ===========================

# Convert bytes to human readable format
# Usage: bytes_to_human <bytes>
bytes_to_human() {
    local bytes="$1"
    if command -v numfmt &>/dev/null; then
        numfmt --to=iec "$bytes"
    else
        echo "${bytes}B"
    fi
}

# Check if required tools are available
# Usage: check_dependencies
check_dependencies() {
    local required_tools=("tar" "sha256sum" "find" "du")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_message "ERROR" "Missing required tools: ${missing_tools[*]}"
        return 1
    fi
    
    # Check optional tools
    local optional_tools=("gpg" "jq" "pv" "numfmt")
    for tool in "${optional_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            log_message "WARN" "Optional tool not available: $tool (reduced functionality)"
        fi
    done
    
    log_message "INFO" "Dependency check completed"
    return 0
}

# Clean up temporary files
# Usage: cleanup_temp_files <temp_dir>
cleanup_temp_files() {
    local temp_dir="${1:-/tmp/backup-$$}"
    
    if [[ -d "$temp_dir" ]]; then
        log_message "DEBUG" "Cleaning up temporary files: $temp_dir"
        # Secure deletion of sensitive temporary files
        find "$temp_dir" -type f -exec shred -uz {} \; 2>/dev/null || {
            find "$temp_dir" -type f -delete 2>/dev/null
        }
        rmdir "$temp_dir" 2>/dev/null || true
    fi
}

# ===========================
# Library Initialization
# ===========================

# Initialize the backup library
# Usage: backup_lib_init [options]
backup_lib_init() {
    log_message "INFO" "Backup library initialized (version $BACKUP_LIB_VERSION)"
    
    # Set up signal handlers for cleanup
    trap 'cleanup_temp_files' EXIT
    trap 'log_message "WARN" "Operation interrupted by user"; exit 130' INT TERM
    
    # Check dependencies
    check_dependencies
    
    return 0
}

# Version information
# Usage: backup_lib_version
backup_lib_version() {
    echo "backup-lib.sh version $BACKUP_LIB_VERSION"
}

# Library metadata
backup_lib_metadata() {
    cat << EOF
Backup Library v${BACKUP_LIB_VERSION}
Functions available:
- log_init, log_message, report_progress
- load_backup_config, get_backup_items
- discover_backup_candidates, is_sensitive_path
- set_secure_permissions, validate_backup_destination, check_sensitive_files
- create_backup_archive, calculate_archive_hash, encrypt_archive
- generate_software_inventory
- bytes_to_human, check_dependencies, cleanup_temp_files
- backup_lib_init, backup_lib_version
EOF
}

# Auto-initialize if run directly (not sourced)
if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
    backup_lib_init "$@"
    if [[ "${1:-}" == "version" ]] || [[ "${1:-}" == "--version" ]]; then
        backup_lib_version
    elif [[ "${1:-}" == "info" ]] || [[ "${1:-}" == "--info" ]]; then
        backup_lib_metadata
    fi
fi