#!/bin/bash

# Check network and service status
# Can run without sudo for most checks

echo "==================================="
echo "Network Configuration Status Check"
echo "==================================="
echo ""

# Show network interfaces
echo "Network Interfaces:"
echo "-------------------"
ip -br addr show
echo ""

# Show public IP
echo "Public IP Address:"
echo "------------------"
curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "Unable to determine"
echo ""
echo ""

# Show listening ports
echo "Listening Ports:"
echo "----------------"
ss -tuln | grep LISTEN | awk '{print $5}' | sed 's/.*:/Port /' | sort -u
echo ""

# Check firewall status
echo "Firewall Status:"
echo "----------------"
sudo ufw status 2>/dev/null || echo "UFW not configured (run setup-firewall.sh)"
echo ""

# Check important services
echo "Service Status:"
echo "---------------"
for service in sshd ssh nginx docker avahi-daemon fail2ban; do
    if systemctl is-active --quiet $service; then
        echo "✓ $service: active"
    else
        echo "✗ $service: inactive/not installed"
    fi
done
echo ""

# Show Docker status if available
if command -v docker &> /dev/null; then
    echo "Docker Containers:"
    echo "------------------"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Docker not accessible"
    echo ""
fi

# Network connectivity test
echo "Network Connectivity:"
echo "--------------------"
ping -c 1 8.8.8.8 &> /dev/null && echo "✓ Internet: Connected" || echo "✗ Internet: Disconnected"
ping -c 1 1.1.1.1 &> /dev/null && echo "✓ DNS: Cloudflare reachable" || echo "✗ DNS: Cloudflare unreachable"
echo ""

# Show Tailscale status if available
if command -v tailscale &> /dev/null; then
    echo "Tailscale Status:"
    echo "-----------------"
    tailscale status --peers=false 2>/dev/null | head -5 || echo "Not connected"
    echo ""
fi

# System resources
echo "System Resources:"
echo "-----------------"
echo "Memory: $(free -h | awk '/^Mem:/ {print $3 " / " $2 " used"}')"
echo "Disk: $(df -h / | awk 'NR==2 {print $3 " / " $2 " used (" $5 ")"}')"
echo "Load: $(uptime | awk -F'load average:' '{print $2}')"
echo "Connections: $(ss -tun | tail -n +2 | wc -l) active"
echo ""

# Recommendations
echo "Next Steps:"
echo "-----------"
if ! sudo ufw status &> /dev/null || [ "$(sudo ufw status 2>/dev/null | grep -c 'Status: active')" -eq 0 ]; then
    echo "1. Configure firewall: sudo bash setup-firewall.sh"
fi
if [ ! -f /etc/sysctl.d/99-network-tune.conf ] && ! grep -q "Network Optimization" /etc/sysctl.conf 2>/dev/null; then
    echo "2. Optimize network: sudo bash optimize-network.sh"
fi
if ! systemctl is-active --quiet nginx; then
    echo "3. Install services: sudo bash install-services.sh"
fi
echo "4. Configure port forwarding on your router for external access"
echo "5. Consider setting up Dynamic DNS for consistent access"
echo ""

echo "==================================="
echo "To test connection from another device:"
echo "ssh $(whoami)@$(hostname -I | awk '{print $1}')"
echo "==================================="