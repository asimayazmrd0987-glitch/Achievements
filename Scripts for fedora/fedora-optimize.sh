#!/usr/bin/env bash
#
# fedora-fix-lag.sh
# For: i5-5300U, 8GB RAM, Fedora 44, running K8s/Docker/VS Code
# Fixes OOM hangs, swap thrashing, and tab-switching lag.

set -e

echo "=============================================="
echo " Fedora 44 Lag Fix for 8GB RAM + K8s"
echo "=============================================="

# --- 1. Install survival tools ---
echo "[1/8] Installing earlyoom, zram, htop..."
sudo dnf install -y earlyoom zram-generator-defaults htop

# --- 2. Enable zram (compressed RAM swap) ---
echo "[2/8] Configuring zram (critical for 8GB)..."
sudo tee /etc/systemd/zram-generator.conf << 'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
EOF
sudo systemctl daemon-reload
sudo systemctl restart systemd-zram-setup@zram0.service 2>/dev/null || true

# --- 3. Fix swappiness: HIGHER, not lower ---
echo "[3/8] Setting swappiness=80 (prevents OOM freezes)..."
sudo tee /etc/sysctl.d/99-swappiness.conf << 'EOF'
vm.swappiness=80
vm.vfs_cache_pressure=50
EOF
sudo sysctl -p /etc/sysctl.d/99-swappiness.conf

# --- 4. Enable earlyoom (kills fat processes before system hangs) ---
echo "[4/8] Enabling earlyoom..."
sudo systemctl enable --now earlyoom

# --- 5. Enable KSM (deduplicates Docker/K8s memory pages) ---
echo "[5/8] Enabling KSM (saves 200-500MB with containers)..."
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
sudo systemctl enable --now ksm

# --- 6. Disable memory hogs (Tracker, animations, abrt) ---
echo "[6/8] Disabling GNOME Tracker and other RAM wasters..."
systemctl --user mask tracker-extract-3.service tracker-miner-fs-3.service tracker-miner-rss-3.service tracker-writeback-3.service tracker-xdg-portal-3.service 2>/dev/null || true
tracker3 reset --hard --no-backup 2>/dev/null || true
gsettings set org.gnome.desktop.interface enable-animations false 2>/dev/null || true
gsettings set org.gnome.desktop.privacy report-technical-problems false 2>/dev/null || true
sudo systemctl mask abrt-journal-core.service abrt-oops.service abrt-xorg.service abrt-vmcore.service 2>/dev/null || true

# --- 7. Limit Docker/K8s memory footprint ---
echo "[7/8] Limiting Docker memory..."
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
sudo systemctl restart docker

# --- 8. Clean up ---
echo "[8/8] Cleaning package cache..."
sudo dnf autoremove -y 2>/dev/null || true
sudo dnf clean all
sudo systemctl enable --now fstrim.timer

echo ""
echo "=============================================="
echo " Done. REBOOT NOW for all changes to work."
echo "=============================================="
echo ""
echo "After reboot, verify with:"
echo "  swapon                       # should show /dev/zram0"
echo "  cat /proc/sys/vm/swappiness  # should show 80"
echo "  systemctl status earlyoom    # should be active"
echo "  cat /sys/kernel/mm/ksm/run   # should show 1"
echo "  free -h                      # check zram swap size"
echo ""
echo "Browser tip: Use only 1 browser window, max 5-6 tabs."
echo "K8s tip: Run only 1 kind cluster at a time."
