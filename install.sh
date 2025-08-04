#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Script configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/backup-manager}"

echo -e "${BLUE}${BOLD}================================${NC}"
echo -e "${BLUE}${BOLD} Backup System Installation${NC}"
echo -e "${BLUE}${BOLD}================================${NC}\n"

# Function to check if a command exists
check_command() {
    local cmd=$1
    local name=$2
    local required=$3
    local install_hint=$4
    
    if command -v "$cmd" &> /dev/null; then
        local version=$(get_version "$cmd")
        echo -e "  ${GREEN}✓${NC} $name found ${version}"
        return 0
    else
        if [[ "$required" == "required" ]]; then
            echo -e "  ${RED}✗${NC} $name ${RED}(REQUIRED)${NC}"
            echo -e "    Install: ${install_hint}"
            return 1
        else
            echo -e "  ${YELLOW}⚠${NC}  $name (optional)"
            echo -e "    Install: ${install_hint}"
            return 0
        fi
    fi
}

# Function to get version info
get_version() {
    local cmd=$1
    case "$cmd" in
        bash) bash --version | head -1 | awk '{print "("$4")"}' 2>/dev/null || echo "" ;;
        gpg) gpg --version | head -1 | awk '{print "("$3")"}' 2>/dev/null || echo "" ;;
        tar) tar --version | head -1 | awk '{print "("$4")"}' 2>/dev/null || echo "" ;;
        cargo) cargo --version | awk '{print "("$2")"}' 2>/dev/null || echo "" ;;
        *) echo "" ;;
    esac
}

# Function to detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        OS_FAMILY=$ID_LIKE
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        OS_FAMILY="macos"
    else
        OS="unknown"
        OS_FAMILY="unknown"
    fi
}

# Prerequisites check
echo -e "${BOLD}Checking prerequisites...${NC}\n"

detect_os
echo -e "Detected OS: ${BLUE}$OS${NC} (family: $OS_FAMILY)\n"

# Track if all required dependencies are met
DEPS_MET=true

# Required dependencies
echo -e "${BOLD}Required dependencies:${NC}"
check_command "bash" "Bash shell" "required" "pacman -S bash | apt install bash" || DEPS_MET=false
check_command "tar" "GNU tar" "required" "pacman -S tar | apt install tar" || DEPS_MET=false
check_command "gzip" "Gzip compression" "required" "pacman -S gzip | apt install gzip" || DEPS_MET=false

echo ""

# Optional dependencies for full functionality
echo -e "${BOLD}Optional dependencies:${NC}"
check_command "gpg" "GPG encryption" "optional" "pacman -S gnupg | apt install gnupg"
check_command "shred" "Secure deletion" "optional" "pacman -S coreutils | apt install coreutils"
check_command "pacman" "Arch package manager" "optional" "Arch Linux only"
check_command "flatpak" "Flatpak packages" "optional" "pacman -S flatpak | apt install flatpak"
check_command "npm" "Node.js packages" "optional" "pacman -S npm | apt install npm"
check_command "pip" "Python packages" "optional" "pacman -S python-pip | apt install python3-pip"

echo ""

# Rust/Cargo for building the UI
echo -e "${BOLD}Build dependencies (for UI):${NC}"
if ! check_command "cargo" "Rust/Cargo" "optional" "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"; then
    echo -e "  ${YELLOW}Note:${NC} Without Rust, only command-line scripts will be available"
    BUILD_UI=false
else
    BUILD_UI=true
fi

echo ""

# Check if required dependencies are met
if [[ "$DEPS_MET" == false ]]; then
    echo -e "${RED}${BOLD}Error: Missing required dependencies!${NC}"
    echo -e "Please install the missing required dependencies and run this script again.\n"
    exit 1
fi

# Check for required files
echo -e "${BOLD}Checking required files...${NC}"
REQUIRED_FILES=(
    "backup-lib.sh"
    "backup-profile-enhanced.sh"
    "backup-profile-secure.sh"
    "backup-config.json"
)

FILES_PRESENT=true
for file in "${REQUIRED_FILES[@]}"; do
    if [[ -f "$SCRIPT_DIR/$file" ]]; then
        echo -e "  ${GREEN}✓${NC} $file"
    else
        echo -e "  ${RED}✗${NC} $file ${RED}(MISSING)${NC}"
        FILES_PRESENT=false
    fi
done

echo ""

if [[ "$FILES_PRESENT" == false ]]; then
    echo -e "${RED}${BOLD}Error: Required files missing!${NC}"
    echo -e "Please ensure all backup scripts are present.\n"
    exit 1
fi

# Installation options
echo -e "${BOLD}Installation Options:${NC}"
echo -e "  Install directory: ${BLUE}$INSTALL_DIR${NC}"
echo -e "  Config directory:  ${BLUE}$CONFIG_DIR${NC}"
echo -e "  Build UI:          ${BLUE}$([ "$BUILD_UI" == true ] && echo "Yes" || echo "No (Rust not available)")${NC}"
echo ""

read -p "Do you want to proceed with installation? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

echo ""

# Create directories
echo -e "${BOLD}Creating directories...${NC}"
mkdir -p "$INSTALL_DIR" 2>/dev/null
mkdir -p "$CONFIG_DIR" 2>/dev/null

# Install scripts
echo -e "${BOLD}Installing backup scripts...${NC}"
for file in "${REQUIRED_FILES[@]}"; do
    if [[ -f "$SCRIPT_DIR/$file" ]]; then
        cp "$SCRIPT_DIR/$file" "$CONFIG_DIR/"
        echo -e "  ${GREEN}✓${NC} Installed $file"
    fi
done

# Create symlinks in install directory
echo -e "\n${BOLD}Creating command symlinks...${NC}"
ln -sf "$CONFIG_DIR/backup-profile-enhanced.sh" "$INSTALL_DIR/backup-enhanced" 2>/dev/null
echo -e "  ${GREEN}✓${NC} backup-enhanced -> $CONFIG_DIR/backup-profile-enhanced.sh"
ln -sf "$CONFIG_DIR/backup-profile-secure.sh" "$INSTALL_DIR/backup-secure" 2>/dev/null
echo -e "  ${GREEN}✓${NC} backup-secure -> $CONFIG_DIR/backup-profile-secure.sh"

# Build and install UI if Rust is available
if [[ "$BUILD_UI" == true ]] && [[ -f "$SCRIPT_DIR/Cargo.toml" ]]; then
    echo -e "\n${BOLD}Building Rust UI...${NC}"
    cd "$SCRIPT_DIR"
    
    if cargo build --release 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} UI built successfully"
        
        if [[ -f "target/release/backup-ui" ]]; then
            cp "target/release/backup-ui" "$INSTALL_DIR/"
            chmod +x "$INSTALL_DIR/backup-ui"
            echo -e "  ${GREEN}✓${NC} UI installed to $INSTALL_DIR/backup-ui"
        fi
    else
        echo -e "  ${YELLOW}⚠${NC}  UI build failed - command-line tools still available"
    fi
fi

# Check if install directory is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo -e "\n${YELLOW}${BOLD}Note:${NC} $INSTALL_DIR is not in your PATH"
    echo -e "Add the following to your shell configuration file (.bashrc, .zshrc, etc.):"
    echo -e "  ${BLUE}export PATH=\"\$PATH:$INSTALL_DIR\"${NC}"
fi

# Success message
echo -e "\n${GREEN}${BOLD}✅ Installation complete!${NC}\n"
echo -e "${BOLD}Available commands:${NC}"
echo -e "  ${BLUE}backup-secure${NC}    - Create secure backup (excludes credentials)"
echo -e "  ${BLUE}backup-enhanced${NC}  - Create complete backup (includes everything)"
if [[ "$BUILD_UI" == true ]] && [[ -f "$INSTALL_DIR/backup-ui" ]]; then
    echo -e "  ${BLUE}backup-ui${NC}        - Launch interactive terminal UI"
fi

echo -e "\n${BOLD}Configuration:${NC}"
echo -e "  Edit ${BLUE}$CONFIG_DIR/backup-config.json${NC} to customize backup items"

echo -e "\n${BOLD}Security Notes:${NC}"
echo -e "  • Use ${BLUE}backup-secure${NC} for long-term storage"
echo -e "  • Use ${BLUE}backup-enhanced${NC} only for immediate OS reinstalls"
echo -e "  • Always use encryption when backing up sensitive data"
echo -e "  • Delete backups securely with: ${BLUE}shred -vuz backup_file${NC}"

echo ""