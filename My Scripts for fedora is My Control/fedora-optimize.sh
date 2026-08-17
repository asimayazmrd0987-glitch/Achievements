#!/usr/bin/env bash
#
# fedora-fix-lag-v2.sh
# For: i5-5300U, 8GB RAM, Fedora 44, running K8s/Docker/VS Code
# Fixes OOM hangs, swap thrashing, tab-switching lag, and file descriptor exhaustion.

set -e

echo "=============================================="
echo " Fedora 44 Lag Fix for 8GB RAM + K8s"
echo "=============================================="

# --- 0. Fix file descriptor limits FIRST (prevents "Too many open files") ---
echo "==> [0/8] Fixing file descriptor and inotify limits..."

# System-wide inotify (VS Code + Docker + Tracker eat these)
if [ ! -f /etc/sysctl.d/99-inotify.conf ]; then
    echo "fs.inotify.max_user_watches = 524288" | sudo tee /etc/sysctl.d/99-inotify.conf >/dev/null
    echo "fs.inotify.max_user_instances = 512" | sudo tee -a /etc/sysctl.d/99-inotify.conf >/dev/null
    sudo sysctl -p /etc/sysctl.d/99-inotify.conf
else
    echo "     inotify limits already set, skipping."
fi

# User file descriptor limits
if [ ! -f /etc/security/limits.d/99-nofile.conf ]; then
    echo "* soft nofile 65536" | sudo tee /etc/security/limits.d/99-nofile.conf >/dev/null
    echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.d/99-nofile.conf >/dev/null
fi

# Systemd limits
sudo mkdir -p /etc/systemd/user.conf.d/ /etc/systemd/system.conf.d/
echo -e "[Manager]\nDefaultLimitNOFILE=65536" | sudo tee /etc/systemd/user.conf.d/limits.conf >/dev/null
echo -e "[Manager]\nDefaultLimitNOFILE=65536" | sudo tee /etc/systemd/system.conf.d/limits.conf >/dev/null
sudo systemctl daemon-reexec

# --- 1. Clean DNF cache (fixes zchunk/mirror corruption) ---
echo "==> [1/8] Cleaning DNF cache..."
sudo dnf clean all
sudo rm -rf /var/cache/libdnf5/* 2>/dev/null || true

# --- 2. Install survival tools ---
echo "==> [2/8] Installing earlyoom, zram, htop..."
sudo dnf install -y earlyoom zram-generator-defaults htop

# --- 3. Enable zram (compressed RAM swap) ---
echo "==> [3/8] Configuring zram (critical for 8GB)..."
sudo tee /etc/systemd/zram-generator.conf << 'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
EOF
sudo systemctl daemon-reload
sudo systemctl restart systemd-zram-setup@zram0.service 2>/dev/null || true

# --- 4. Fix swappiness: HIGHER, not lower ---
echo "==> [4/8] Setting swappiness=80 (prevents OOM freezes)..."
sudo tee /etc/sysctl.d/99-swappiness.conf << 'EOF'
vm.swappiness=80
vm.vfs_cache_pressure=50
EOF
sudo sysctl -p /etc/sysctl.d/99-swappiness.conf

# --- 5. Enable earlyoom (kills fat processes before system hangs) ---
echo "==> [5/8] Enabling earlyoom..."
sudo systemctl enable --now earlyoom

# --- 6. Enable KSM (deduplicates Docker/K8s memory pages) ---
echo "==> [6/8] Enabling KSM (saves 200-500MB with containers)..."
sudo tee /etc/systemd/system/ksm.service << 'EOF'
[Unit]
Description=Kernel Samepage Merging

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'echo 1 > /sys/kernel/mm/ksm/run && echo 1000 > /sys/kernel/mm/ksm/sleep_millisecs'
ExecStop=/bin/sh -c 'echo 0 > /sys/kernel/mm/ksm/run'

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now ksm 2>/dev/null || true

# --- 7. Disable memory hogs (Tracker, animations, abrt) ---
echo "==> [7/8] Disabling GNOME Tracker and other RAM wasters..."
systemctl --user mask tracker-extract-3.service tracker-miner-fs-3.service tracker-miner-rss-3.service tracker-writeback-3.service tracker-xdg-portal-3.service 2>/dev/null || true
tracker3 reset --hard --no-backup 2>/dev/null || true
gsettings set org.gnome.desktop.interface enable-animations false 2>/dev/null || true
gsettings set org.gnome.desktop.privacy report-technical-problems false 2>/dev/null || true
sudo systemctl mask abrt-journal-core.service abrt-oops.service abrt-xorg.service abrt-vmcore.service 2>/dev/null || true

# --- 8. Limit Docker/K8s memory footprint ---
echo "==> [8/8] Limiting Docker memory..."
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json << 'EOF'
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
sudo systemctl restart docker 2>/dev/null || true

# --- 9. Clean up ---
echo "==> [9/8] Cleaning package cache..."
sudo dnf autoremove -y 2>/dev/null || true
sudo dnf clean all
sudo systemctl enable --now fstrim.timer 2>/dev/null || true

echo ""
echo "=============================================="
echo " Done. REBOOT NOW for all changes to work."
echo "=============================================="
echo ""
echo "After reboot, verify with:"
echo "  ulimit -n                    # should show 65536"
echo "  cat /proc/sys/fs/inotify/max_user_watches  # should show 524288"
echo "  swapon                       # should show /dev/zram0"
echo "  cat /proc/sys/vm/swappiness  # should show 80"
echo "  systemctl status earlyoom    # should be active"
echo "  cat /sys/kernel/mm/ksm/run   # should show 1"
echo "  free -h                      # check zram swap size"
echo ""
echo "Browser tip: Use only 1 browser window, max 5-6 tabs."
echo "K8s tip: Run only 1 kind cluster at a time."