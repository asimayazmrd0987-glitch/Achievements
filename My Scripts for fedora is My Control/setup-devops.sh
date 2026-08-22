#!/usr/bin/env bash
#
# setup-devops.sh
# One-shot installer for essential DevOps tools on Linux.
# Supports: Fedora (dnf/dnf5), Ubuntu/Debian (apt), Arch Linux (pacman)
#
# Usage:
#   chmod +x setup-devops.sh
#   ./setup-devops.sh
#
# Tools installed:
#   - Docker + Docker Compose
#   - Kubernetes: kubectl, kind, Helm
#   - Terraform
#   - AWS CLI v2
#   - Git, curl, wget, htop, vim/nano
#   - Optional: VS Code, minikube, kubectx, kubens
#
# Safe to re-run. Every step is idempotent.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging helpers
info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERR]${NC}  $*" >&2; }

# Detect distro
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    elif command -v lsb_release &>/dev/null; then
        lsb_release -si | tr '[:upper:]' '[:lower:]'
    else
        echo "unknown"
    fi
}

DISTRO=$(detect_distro)
info "Detected distro: $DISTRO"

# Package manager wrapper
pkg_install() {
    case "$DISTRO" in
        fedora|rhel|centos|rocky|almalinux)
            # Fedora 44+ uses dnf5
            if command -v dnf5 &>/dev/null; then
                sudo dnf5 install -y "$@"
            else
                sudo dnf install -y "$@"
            fi
            ;;
        ubuntu|debian|pop)
            sudo apt-get update
            sudo apt-get install -y "$@"
            ;;
        arch|manjaro|endeavouros)
            sudo pacman -Sy --noconfirm "$@"
            ;;
        *)
            error "Unsupported distro: $DISTRO"
            exit 1
            ;;
    esac
}

# Check if a command exists
has() {
    command -v "$1" &>/dev/null
}

# ============================
# 0. Pre-flight checks
# ============================
info "Checking privileges..."
if ! sudo -n true 2>/dev/null; then
    warn "This script requires sudo. You may be prompted for your password."
fi

# ============================
# 1. Core system tools
# ============================
info "[1/10] Installing core system tools..."
pkg_install curl wget git vim nano htop tree unzip tar gzip     bash-completion ca-certificates gnupg lsb-release     2>/dev/null || true

ok "Core tools installed."

# ============================
# 2. Docker
# ============================
info "[2/10] Setting up Docker..."

if has docker; then
    ok "Docker already installed: $(docker --version)"
else
    case "$DISTRO" in
        fedora|rhel|rocky|almalinux)
            if ! has dnf5; then
                sudo dnf install -y dnf-plugins-core
            fi
            sudo dnf config-manager addrepo                 --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo                 2>/dev/null ||             sudo dnf config-manager --add-repo                 https://download.docker.com/linux/fedora/docker-ce.repo
            pkg_install docker-ce docker-ce-cli containerd.io                          docker-buildx-plugin docker-compose-plugin
            ;;
        ubuntu|debian|pop)
            sudo install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg |                 sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" |                 sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
            sudo apt-get update
            pkg_install docker-ce docker-ce-cli containerd.io                          docker-buildx-plugin docker-compose-plugin
            ;;
        arch|manjaro)
            sudo pacman -Sy --noconfirm docker docker-compose
            ;;
    esac

    sudo systemctl enable --now docker
    sudo usermod -aG docker "$USER"
    ok "Docker installed and service started."
    warn "Log out and back in (or run 'newgrp docker') to use Docker without sudo."
fi

# ============================
# 3. kubectl
# ============================
info "[3/10] Installing kubectl..."

if has kubectl; then
    ok "kubectl already installed: $(kubectl version --client -o json | grep gitVersion | cut -d'"' -f4 2>/dev/null || kubectl version --client | head -1)"
else
    KUBECTL_URL="https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    curl -LO "$KUBECTL_URL"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/kubectl
    ok "kubectl installed."
fi

# ============================
# 4. kind (Kubernetes in Docker)
# ============================
info "[4/10] Installing kind..."

if has kind; then
    ok "kind already installed: $(kind version)"
else
    KIND_VERSION="v0.32.0"
    curl -Lo ./kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64"
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
    ok "kind ${KIND_VERSION} installed."
fi

# ============================
# 5. Helm
# ============================
info "[5/10] Installing Helm..."

if has helm; then
    ok "Helm already installed: $(helm version --short)"
else
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    ok "Helm installed."
fi

# ============================
# 6. Terraform
# ============================
info "[6/10] Installing Terraform..."

if has terraform; then
    ok "Terraform already installed: $(terraform version | head -1)"
else
    case "$DISTRO" in
        fedora|rhel|rocky|almalinux)
            sudo dnf install -y dnf-plugins-core
            sudo dnf config-manager addrepo                 --from-repofile=https://rpm.releases.hashicorp.com/fedora/hashicorp.repo                 2>/dev/null ||             sudo dnf config-manager --add-repo                 https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
            pkg_install terraform
            ;;
        ubuntu|debian|pop)
            wget -O- https://apt.releases.hashicorp.com/gpg |                 sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" |                 sudo tee /etc/apt/sources.list.d/hashicorp.list
            sudo apt-get update
            pkg_install terraform
            ;;
        arch|manjaro)
            yay -S terraform-bin 2>/dev/null ||             sudo pacman -Sy --noconfirm terraform
            ;;
    esac
    ok "Terraform installed."
fi

# ============================
# 7. AWS CLI v2
# ============================
info "[7/10] Installing AWS CLI v2..."

if has aws; then
    ok "AWS CLI already installed: $(aws --version)"
else
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    sudo ./aws/install --update
    rm -rf aws awscliv2.zip
    ok "AWS CLI v2 installed."
fi

# ============================
# 8. VS Code (optional but useful)
# ============================
info "[8/10] Installing VS Code..."

if has code; then
    ok "VS Code already installed: $(code --version | head -1)"
else
    case "$DISTRO" in
        fedora|rhel|rocky|almalinux)
            sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
            sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
            pkg_install code
            ;;
        ubuntu|debian|pop)
            wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
            sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
            echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" |                 sudo tee /etc/apt/sources.list.d/vscode.list
            rm -f packages.microsoft.gpg
            sudo apt-get update
            pkg_install code
            ;;
        arch|manjaro)
            yay -S visual-studio-code-bin 2>/dev/null ||             sudo pacman -Sy --noconfirm code
            ;;
    esac
    ok "VS Code installed."
fi

# ============================
# 9. Optional: kubectx + kubens
# ============================
info "[9/10] Installing kubectx & kubens..."

if has kubectx; then
    ok "kubectx already installed."
else
    KUBECTX_VERSION="0.9.5"
    curl -Lo /tmp/kubectx.tar.gz "https://github.com/ahmetb/kubectx/archive/refs/tags/v${KUBECTX_VERSION}.tar.gz"
    tar -xzf /tmp/kubectx.tar.gz -C /tmp
    sudo cp /tmp/kubectx-${KUBECTX_VERSION}/kubectx /usr/local/bin/
    sudo cp /tmp/kubectx-${KUBECTX_VERSION}/kubens /usr/local/bin/
    rm -rf /tmp/kubectx*
    ok "kubectx & kubens installed."
fi

# ============================
# 10. Optional: minikube
# ============================
info "[10/10] Installing minikube..."

if has minikube; then
    ok "minikube already installed: $(minikube version | head -1)"
else
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-latest.x86_64.rpm
    sudo rpm -Uvh minikube-latest.x86_64.rpm || sudo dnf install -y ./minikube-latest.x86_64.rpm
    rm -f minikube-latest.x86_64.rpm
    ok "minikube installed."
fi

# ============================
# Verification
# ============================
echo ""
echo "=============================================="
echo "  DevOps Toolkit - Installation Summary"
echo "=============================================="
echo ""

check_tool() {
    if has "$1"; then
        printf "  ${GREEN}✓${NC} %-15s %s\n" "$1" "$("$1" --version 2>/dev/null | head -1 || echo 'installed')"
    else
        printf "  ${RED}✗${NC} %-15s %s\n" "$1" "not found"
    fi
}

check_tool docker
check_tool kubectl
check_tool kind
check_tool helm
check_tool terraform
check_tool aws
check_tool git
check_tool code
check_tool minikube
check_tool kubectx

echo ""
echo "=============================================="
echo "  Next Steps"
echo "=============================================="
echo ""
echo "  1. Log out and back in (or reboot) for"
echo "     Docker group membership to take effect."
echo ""
echo "  2. Verify Docker works:"
echo "     docker run hello-world"
echo ""
echo "  3. Create your first kind cluster:"
echo "     kind create cluster"
echo "     kubectl get nodes"
echo ""
echo "  4. Configure AWS CLI:"
echo "     aws configure"
echo ""
echo "=============================================="
