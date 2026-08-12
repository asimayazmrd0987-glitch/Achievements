#!/bin/bash
# SoftMaker FreeOffice 2024 Installer for Fedora
# Run: chmod +x install-freeoffice.sh && ./install-freeoffice.sh

set -e

echo "=========================================="
echo "  SoftMaker FreeOffice 2024 Installer"
echo "=========================================="

# Step 1: Ensure curl is installed
echo "[1/3] Checking curl..."
if ! command -v curl &> /dev/null; then
    echo "  -> curl not found. Installing..."
    sudo dnf install -y curl
else
    echo "  -> curl already installed."
fi

# Step 2: Download and run SoftMaker installer
echo "[2/3] Downloading and installing FreeOffice 2024..."
curl -fsSL https://softmaker.net/down/install-softmaker-freeoffice-2024.sh | sudo bash

# Step 3: Update system packages
echo "[3/3] Running system upgrade..."
sudo -E dnf upgrade -y

echo ""
echo "=========================================="
echo "  FreeOffice 2024 Installation Complete!"
echo "=========================================="
echo ""
echo "Launch with: textmaker24, planmaker24, or presentations24"
