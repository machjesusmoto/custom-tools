#!/bin/bash

# Install common network services
# Run with sudo: sudo bash install-services.sh

echo "Installing common network services..."

# Detect package manager
if command -v pacman &> /dev/null; then
    PKG_MGR="pacman"
    INSTALL_CMD="pacman -S --noconfirm"
elif command -v apt-get &> /dev/null; then
    PKG_MGR="apt"
    INSTALL_CMD="apt-get install -y"
    apt-get update
elif command -v dnf &> /dev/null; then
    PKG_MGR="dnf"
    INSTALL_CMD="dnf install -y"
else
    echo "Unsupported package manager"
    exit 1
fi

echo "Using package manager: $PKG_MGR"

# Install SSH server if not present
if ! systemctl is-active --quiet sshd && ! systemctl is-active --quiet ssh; then
    echo "Installing SSH server..."
    if [ "$PKG_MGR" = "pacman" ]; then
        $INSTALL_CMD openssh
        systemctl enable --now sshd
    else
        $INSTALL_CMD openssh-server
        systemctl enable --now ssh
    fi
fi

# Install fail2ban for security
echo "Installing fail2ban for brute force protection..."
$INSTALL_CMD fail2ban

# Configure fail2ban for SSH
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
EOF

systemctl enable --now fail2ban

# Install network tools
echo "Installing network utilities..."
if [ "$PKG_MGR" = "pacman" ]; then
    $INSTALL_CMD net-tools inetutils nmap netcat tcpdump wireshark-cli iperf3 mtr traceroute
else
    $INSTALL_CMD net-tools nmap netcat tcpdump wireshark iperf3 mtr traceroute
fi

# Install web server (nginx)
echo "Installing nginx web server..."
$INSTALL_CMD nginx
systemctl enable nginx

# Create a simple welcome page
cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Server Ready</title>
</head>
<body>
    <h1>Server is accepting connections</h1>
    <p>This server has been configured to accept various types of network connections.</p>
</body>
</html>
EOF

systemctl start nginx

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    if [ "$PKG_MGR" = "pacman" ]; then
        $INSTALL_CMD docker docker-compose
    else
        curl -fsSL https://get.docker.com | sh
    fi
    systemctl enable --now docker
    usermod -aG docker $SUDO_USER 2>/dev/null
fi

# Install avahi for network discovery
echo "Installing Avahi for network discovery..."
$INSTALL_CMD avahi
if [ "$PKG_MGR" = "pacman" ]; then
    $INSTALL_CMD nss-mdns
else
    $INSTALL_CMD avahi-daemon
fi
systemctl enable --now avahi-daemon

# Enable and configure SSH
sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#Port 22/Port 22/' /etc/ssh/sshd_config

# Add some security but keep it accessible
echo "" >> /etc/ssh/sshd_config
echo "# Connection settings" >> /etc/ssh/sshd_config
echo "MaxAuthTries 6" >> /etc/ssh/sshd_config
echo "MaxSessions 10" >> /etc/ssh/sshd_config
echo "ClientAliveInterval 300" >> /etc/ssh/sshd_config
echo "ClientAliveCountMax 2" >> /etc/ssh/sshd_config

systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null

echo ""
echo "Service installation complete!"
echo ""
echo "Services status:"
systemctl is-active sshd ssh nginx docker avahi-daemon fail2ban | xargs -I {} echo "- {}"
echo ""
echo "Your server is now configured to accept connections on multiple ports."
echo "Remember to:"
echo "1. Run the firewall setup script: sudo bash setup-firewall.sh"
echo "2. Run the network optimization script: sudo bash optimize-network.sh"
echo "3. Configure port forwarding on your router for external access"
echo "4. Set up Dynamic DNS if you don't have a static IP"