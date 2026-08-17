#!/usr/bin/env bash
#
# fedora-optimize.sh
# Permanent performance tuning for Fedora 44 on low-RAM (8GB) laptops.
# Run with: chmod +x fedora-optimize.sh && ./fedora-optimize.sh
#
# What this does:
#   1. Installs htop (if missing)
#   2. Disables GNOME Tracker file indexing (big CPU/disk hog on low RAM)
#   3. Disables GNOME animations (permanent, per-user)
#   4. Cleans dnf cache + removes old kernels/orphaned packages
#   5. Sets vm.swappiness=10 permanently via sysctl.d
#   6. Enables fstrim.timer for SSD health/speed
#
# Safe to re-run — every step is idempotent.

set -e

echo "=============================================="
echo " Fedora 44 Performance Optimization Script"
echo "=============================================="

# --- 1. Install htop for future monitoring ---
if ! command -v htop &>/dev/null; then
    echo "[1/6] Installing htop..."
    sudo dnf install htop -y
else
    echo "[1/6] htop already installed, skipping."
fi

# --- 2. Disable GNOME Tracker indexing ---
echo "[2/6] Disabling GNOME Tracker file indexing..."
systemctl --user mask tracker-extract-3.service \
                       tracker-miner-fs-3.service \
                       tracker-miner-rss-3.service \
                       tracker-writeback-3.service \
                       tracker-xdg-portal-3.service 2>/dev/null || true
tracker3 reset --hard --no-backup 2>/dev/null || true

# --- 3. Disable GNOME animations permanently ---
echo "[3/6] Disabling GNOME animations..."
gsettings set org.gnome.desktop.interface enable-animations false 2>/dev/null || true

# --- 4. Clean dnf cache + remove old kernels/orphans ---
echo "[4/6] Cleaning package cache and removing unused packages..."
sudo dnf autoremove -y
sudo dnf clean all

# --- 5. Tune swappiness permanently ---
echo "[5/6] Setting vm.swappiness=10 permanently..."
SWAPPINESS_FILE="/etc/sysctl.d/99-swappiness.conf"
if [ -f "$SWAPPINESS_FILE" ]; then
    sudo sed -i 's/^vm.swappiness=.*/vm.swappiness=10/' "$SWAPPINESS_FILE"
else
    echo "vm.swappiness=10" | sudo tee "$SWAPPINESS_FILE" > /dev/null
fi
sudo sysctl -p "$SWAPPINESS_FILE"

# --- 6. Enable SSD trim timer ---
echo "[6/6] Enabling fstrim.timer for SSD..."
sudo systemctl enable --now fstrim.timer

echo ""
echo "=============================================="
echo " Done. Recommended: log out and back in"
echo " (or reboot) so animation/tracker changes"
echo " fully take effect."
echo "=============================================="
echo ""
echo "Quick check commands you can run anytime:"
echo "  free -h                  # memory usage"
echo "  cat /proc/sys/vm/swappiness   # confirm swappiness=10"
echo "  systemctl status fstrim.timer # confirm trim is active"
echo "  htop                     # live resource monitor"
