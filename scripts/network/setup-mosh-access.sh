#!/usr/bin/env bash
# setup-mosh-access.sh - Configure system for secure remote access via Mosh
# Version: 1.0.0
# Last Updated: August 15, 2025
# Purpose: Install and configure Mosh (Mobile Shell) for better remote access

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log() {
    echo -e "${GREEN}[MOSH]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root directly"
        error "It will use sudo when needed for specific commands"
        exit 1
    fi
}

# Install Mosh
install_mosh() {
    log "Installing Mosh..."
    
    # Detect package manager and install
    if command -v pacman &> /dev/null; then
        # Arch Linux
        sudo pacman -S --noconfirm mosh
    elif command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        sudo apt-get update
        sudo apt-get install -y mosh
    elif command -v dnf &> /dev/null; then
        # Fedora
        sudo dnf install -y mosh
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS
        sudo yum install -y mosh
    else
        error "Unsupported package manager. Please install Mosh manually."
        exit 1
    fi
    
    success "Mosh installed successfully"
}

# Configure firewall for Mosh
configure_firewall() {
    log "Configuring firewall for Mosh..."
    
    # Check which firewall is in use
    if command -v ufw &> /dev/null; then
        # UFW (Ubuntu/Debian)
        info "Configuring UFW firewall..."
        
        # Allow SSH (required for Mosh initial connection)
        sudo ufw allow 22/tcp comment 'SSH for Mosh'
        
        # Allow Mosh UDP port range
        sudo ufw allow 60000:61000/udp comment 'Mosh UDP ports'
        
        # Enable UFW if not already enabled
        if ! sudo ufw status | grep -q "Status: active"; then
            warning "UFW is not active. Enabling UFW..."
            sudo ufw --force enable
        fi
        
        success "UFW configured for Mosh"
        
    elif command -v firewall-cmd &> /dev/null; then
        # firewalld (Fedora/RHEL/CentOS)
        info "Configuring firewalld..."
        
        # Allow SSH
        sudo firewall-cmd --permanent --add-service=ssh
        
        # Allow Mosh UDP ports
        sudo firewall-cmd --permanent --add-port=60000-61000/udp
        
        # Reload firewall
        sudo firewall-cmd --reload
        
        success "firewalld configured for Mosh"
        
    elif command -v iptables &> /dev/null; then
        # iptables (generic)
        info "Configuring iptables..."
        
        # Allow SSH
        sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
        
        # Allow Mosh UDP ports
        sudo iptables -A INPUT -p udp --dport 60000:61000 -j ACCEPT
        
        # Save rules (method varies by distro)
        if command -v iptables-save &> /dev/null; then
            sudo iptables-save > /etc/iptables/rules.v4 2>/dev/null || \
            sudo iptables-save > /etc/sysconfig/iptables 2>/dev/null || \
            warning "Could not save iptables rules automatically"
        fi
        
        success "iptables configured for Mosh"
    else
        warning "No supported firewall found. Please configure manually."
        info "Mosh requires UDP ports 60000-61000 to be open"
    fi
}

# Configure SSH for better security
configure_ssh() {
    log "Checking SSH configuration..."
    
    local ssh_config="/etc/ssh/sshd_config"
    
    if [[ -f "$ssh_config" ]]; then
        # Check if SSH is configured securely
        if grep -q "^PermitRootLogin yes" "$ssh_config"; then
            warning "Root login is enabled in SSH. Consider disabling for security."
            info "To disable: sudo sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' $ssh_config"
        fi
        
        if ! grep -q "^PubkeyAuthentication yes" "$ssh_config"; then
            warning "Public key authentication not explicitly enabled."
            info "Consider enabling: echo 'PubkeyAuthentication yes' | sudo tee -a $ssh_config"
        fi
        
        success "SSH configuration checked"
    else
        warning "SSH config not found at $ssh_config"
    fi
}

# Test Mosh installation
test_mosh() {
    log "Testing Mosh installation..."
    
    # Check if mosh-server is available
    if command -v mosh-server &> /dev/null; then
        success "mosh-server is installed and available"
        
        # Get version
        local version=$(mosh --version 2>&1 | head -n1)
        info "Mosh version: $version"
    else
        error "mosh-server not found. Installation may have failed."
        return 1
    fi
    
    # Check if locale is set (Mosh requires this)
    if [[ -z "${LC_ALL:-}" ]] && [[ -z "${LANG:-}" ]]; then
        warning "Locale not set. Mosh requires a UTF-8 locale."
        info "Setting locale to en_US.UTF-8..."
        export LC_ALL=en_US.UTF-8
        export LANG=en_US.UTF-8
        
        # Make it permanent
        echo "export LC_ALL=en_US.UTF-8" >> ~/.bashrc
        echo "export LANG=en_US.UTF-8" >> ~/.bashrc
    fi
    
    success "Mosh is ready to use"
}

# Display connection information
display_info() {
    log "Setup complete! Here's how to connect:"
    echo
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Mosh Remote Access Setup Complete${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo
    
    # Get IP addresses
    local ip_addresses=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1')
    
    echo "Your system is now configured for Mosh access."
    echo
    echo "To connect from a remote machine:"
    echo -e "${YELLOW}mosh username@your-server-ip${NC}"
    echo
    echo "Your current IP addresses:"
    while IFS= read -r ip; do
        echo -e "  ${CYAN}• $ip${NC}"
    done <<< "$ip_addresses"
    echo
    echo "Firewall rules configured:"
    echo "  • SSH (TCP port 22) - for initial connection"
    echo "  • Mosh (UDP ports 60000-61000) - for session data"
    echo
    echo -e "${YELLOW}Important Notes:${NC}"
    echo "1. Mosh requires SSH for initial authentication"
    echo "2. Make sure your SSH keys are configured"
    echo "3. Mosh provides better performance on unstable connections"
    echo "4. Sessions persist even if network changes (WiFi to cellular, etc.)"
    echo
    echo -e "${GREEN}Benefits of Mosh over SSH:${NC}"
    echo "  ✓ Survives network changes and disconnections"
    echo "  ✓ Instant response (predictive local echo)"
    echo "  ✓ Works better on high-latency connections"
    echo "  ✓ Automatic roaming between networks"
    echo
    
    # Show firewall status
    if command -v ufw &> /dev/null; then
        echo "Current firewall status:"
        sudo ufw status numbered | grep -E "(SSH|Mosh|60000)" || true
    fi
    
    echo
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
}

# Main execution
main() {
    clear
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}     Mosh (Mobile Shell) Setup for Secure Remote Access${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo
    
    # Check prerequisites
    check_root
    
    # Check if Mosh is already installed
    if command -v mosh &> /dev/null; then
        info "Mosh is already installed"
        
        # Ask if user wants to reconfigure
        read -p "Do you want to reconfigure firewall rules? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Skipping installation, configuring firewall only..."
        else
            install_mosh
        fi
    else
        install_mosh
    fi
    
    # Configure firewall
    configure_firewall
    
    # Configure SSH
    configure_ssh
    
    # Test installation
    test_mosh
    
    # Display connection info
    display_info
    
    success "Mosh setup completed successfully!"
}

# Run main function
main "$@"