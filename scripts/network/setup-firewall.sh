#!/bin/bash

# Setup firewall to accept most connections while maintaining security
# Run this script with sudo: sudo bash setup-firewall.sh

echo "Setting up firewall to accept connections..."

# Enable UFW
ufw --force enable

# Set default policies
ufw default deny incoming
ufw default allow outgoing
ufw default allow routed

# Allow common services
echo "Configuring common service ports..."

# SSH (already listening)
ufw allow 22/tcp comment 'SSH'

# HTTP and HTTPS
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'

# FTP
ufw allow 21/tcp comment 'FTP'
ufw allow 20/tcp comment 'FTP-data'
ufw allow 990/tcp comment 'FTPS'
ufw allow 40000:50000/tcp comment 'FTP passive mode'

# Mail services
ufw allow 25/tcp comment 'SMTP'
ufw allow 587/tcp comment 'SMTP submission'
ufw allow 465/tcp comment 'SMTPS'
ufw allow 110/tcp comment 'POP3'
ufw allow 995/tcp comment 'POP3S'
ufw allow 143/tcp comment 'IMAP'
ufw allow 993/tcp comment 'IMAPS'

# Database services
ufw allow 3306/tcp comment 'MySQL/MariaDB'
ufw allow 5432/tcp comment 'PostgreSQL'
ufw allow 27017/tcp comment 'MongoDB'
ufw allow 6379/tcp comment 'Redis'

# Web development
ufw allow 3000/tcp comment 'Node.js dev'
ufw allow 3001/tcp comment 'React dev'
ufw allow 4200/tcp comment 'Angular dev'
ufw allow 5000/tcp comment 'Flask dev'
ufw allow 5173/tcp comment 'Vite dev'
ufw allow 8000/tcp comment 'Django dev'
ufw allow 8080/tcp comment 'Tomcat/Jenkins'
ufw allow 8081/tcp comment 'Alternative HTTP'
ufw allow 8443/tcp comment 'Alternative HTTPS'
ufw allow 9000/tcp comment 'PHP-FPM'

# Container services
ufw allow 2375/tcp comment 'Docker API'
ufw allow 2376/tcp comment 'Docker SSL'
ufw allow 2377/tcp comment 'Docker Swarm'
ufw allow 4789/udp comment 'Docker overlay'
ufw allow 7946/tcp comment 'Docker container network'
ufw allow 7946/udp comment 'Docker container network'

# Remote access
ufw allow 3389/tcp comment 'RDP'
ufw allow 5900/tcp comment 'VNC'
ufw allow 5901/tcp comment 'VNC display 1'

# File sharing
ufw allow 137/udp comment 'NetBIOS Name Service'
ufw allow 138/udp comment 'NetBIOS Datagram'
ufw allow 139/tcp comment 'NetBIOS Session'
ufw allow 445/tcp comment 'SMB/CIFS'
ufw allow 2049/tcp comment 'NFS'
ufw allow 111/tcp comment 'NFS portmapper'

# Media streaming
ufw allow 1935/tcp comment 'RTMP'
ufw allow 8554/tcp comment 'RTSP'
ufw allow 32400/tcp comment 'Plex'

# Gaming
ufw allow 25565/tcp comment 'Minecraft'
ufw allow 27015/tcp comment 'Source engine games'
ufw allow 27015/udp comment 'Source engine games'

# VPN
ufw allow 1194/udp comment 'OpenVPN'
ufw allow 500/udp comment 'IPSec/IKE'
ufw allow 4500/udp comment 'IPSec NAT traversal'
ufw allow 1701/udp comment 'L2TP'

# DNS
ufw allow 53/tcp comment 'DNS'
ufw allow 53/udp comment 'DNS'

# DHCP
ufw allow 67/udp comment 'DHCP server'
ufw allow 68/udp comment 'DHCP client'

# Time sync
ufw allow 123/udp comment 'NTP'

# Monitoring
ufw allow 161/udp comment 'SNMP'
ufw allow 162/udp comment 'SNMP trap'
ufw allow 9090/tcp comment 'Prometheus'
ufw allow 3100/tcp comment 'Loki'
ufw allow 9093/tcp comment 'Alertmanager'

# Message queues
ufw allow 5672/tcp comment 'RabbitMQ/AMQP'
ufw allow 15672/tcp comment 'RabbitMQ management'
ufw allow 9092/tcp comment 'Kafka'
ufw allow 2181/tcp comment 'Zookeeper'

# Allow local network access (adjust subnet as needed)
ufw allow from 10.0.0.0/8 comment 'Private network 10.x'
ufw allow from 172.16.0.0/12 comment 'Private network 172.x'
ufw allow from 192.168.0.0/16 comment 'Private network 192.168.x'

# Allow Tailscale network
ufw allow from 100.64.0.0/10 comment 'Tailscale CGNAT'

# Enable logging
ufw logging on
ufw logging low

# Show status
echo ""
echo "Firewall configuration complete!"
echo ""
ufw status verbose

echo ""
echo "Additional recommendations:"
echo "1. Your SSH is already configured and listening on port 22"
echo "2. Consider using fail2ban for brute force protection"
echo "3. For production, review and remove unnecessary ports"
echo "4. Monitor logs at /var/log/ufw.log"
echo ""
echo "To temporarily disable firewall: sudo ufw disable"
echo "To check status: sudo ufw status verbose"
echo "To remove a rule: sudo ufw delete allow <port>"