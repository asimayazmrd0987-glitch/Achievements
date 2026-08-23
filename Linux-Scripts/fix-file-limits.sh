#!/bin/bash
set -e

echo "=== Fixing File Descriptor & inotify Limits ==="

# 1. Increase inotify watches (VS Code + Tracker + Docker eat these)
echo "fs.inotify.max_user_watches = 524288" | sudo tee /etc/sysctl.d/99-inotify.conf
echo "fs.inotify.max_user_instances = 512" | sudo tee -a /etc/sysctl.d/99-inotify.conf
sudo sysctl -p /etc/sysctl.d/99-inotify.conf

# 2. Increase system-wide file descriptor limits
echo "* soft nofile 65536" | sudo tee /etc/security/limits.d/99-nofile.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.d/99-nofile.conf

# 3. Increase systemd user manager limits
sudo mkdir -p /etc/systemd/user.conf.d/
sudo tee /etc/systemd/user.conf.d/limits.conf << 'EOF'
[Manager]
DefaultLimitNOFILE=65536
EOF

sudo mkdir -p /etc/systemd/system.conf.d/
sudo tee /etc/systemd/system.conf.d/limits.conf << 'EOF'
[Manager]
DefaultLimitNOFILE=65536
EOF

# 4. Restart systemd daemon (no reboot needed for this part)
sudo systemctl daemon-reexec

echo "=== Done. Log out and back in for user limits to apply. ==="
echo "Verify after login with: ulimit -n"
