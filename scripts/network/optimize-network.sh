#!/bin/bash

# Network optimization for accepting connections
# Run with sudo: sudo bash optimize-network.sh

echo "Optimizing network settings for accepting connections..."

# Backup current sysctl settings
cp /etc/sysctl.conf /etc/sysctl.conf.backup.$(date +%Y%m%d)

# Network optimization settings
cat >> /etc/sysctl.conf << 'EOF'

# Network Optimization for Server
# Added on $(date)

# Increase system file descriptor limit
fs.file-max = 2097152

# Increase socket listen backlog
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535

# Increase network buffers
net.core.rmem_default = 31457280
net.core.rmem_max = 134217728
net.core.wmem_default = 31457280
net.core.wmem_max = 134217728
net.core.netdev_max_backlog = 65536
net.core.optmem_max = 25165824

# TCP optimization
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_keepalive_time = 120
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 5

# Connection tracking
net.netfilter.nf_conntrack_max = 524288
net.nf_conntrack_max = 524288
net.ipv4.netfilter.ip_conntrack_max = 524288

# Enable TCP Fast Open
net.ipv4.tcp_fastopen = 3

# Increase ephemeral port range
net.ipv4.ip_local_port_range = 10000 65535

# Enable IP forwarding (useful for Docker/VPN)
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# Disable IPv6 if not needed (uncomment to disable)
# net.ipv6.conf.all.disable_ipv6 = 1
# net.ipv6.conf.default.disable_ipv6 = 1

# Security settings (balanced for accepting connections)
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Allow more connections
net.core.somaxconn = 65535
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_tw_reuse = 1

EOF

# Apply settings
sysctl -p

# Increase ulimits for the system
cat >> /etc/security/limits.conf << 'EOF'

# Increase limits for accepting connections
* soft nofile 1048576
* hard nofile 1048576
* soft nproc 65535
* hard nproc 65535
root soft nofile 1048576
root hard nofile 1048576
root soft nproc 65535
root hard nproc 65535

EOF

# Configure systemd limits
mkdir -p /etc/systemd/system.conf.d/
cat > /etc/systemd/system.conf.d/10-limits.conf << 'EOF'
[Manager]
DefaultLimitNOFILE=1048576
DefaultLimitNPROC=65535
EOF

mkdir -p /etc/systemd/user.conf.d/
cat > /etc/systemd/user.conf.d/10-limits.conf << 'EOF'
[Manager]
DefaultLimitNOFILE=1048576
DefaultLimitNPROC=65535
EOF

# Enable BBR congestion control if available
modprobe tcp_bbr 2>/dev/null
echo "tcp_bbr" >> /etc/modules-load.d/modules.conf 2>/dev/null

echo ""
echo "Network optimization complete!"
echo ""
echo "Current network settings:"
sysctl net.core.somaxconn
sysctl net.ipv4.tcp_max_syn_backlog
sysctl fs.file-max
echo ""
echo "Note: A system restart may be required for all settings to take effect."
echo "You can apply most settings immediately with: sudo sysctl -p"