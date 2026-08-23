# DevOps Toolkit Installer

A single, portable shell script that installs the essential DevOps toolchain on any major Linux distribution.

## Supported Distros

| Distro | Package Manager |
|--------|----------------|
| Fedora 40+ | dnf / dnf5 |
| Ubuntu 22.04+ | apt |
| Debian 12+ | apt |
| Arch Linux | pacman |
| Manjaro | pacman |
| Omarchy | pacman |

## Tools Installed

| Tool | Purpose |
|------|---------|
| **Docker** | Container runtime + Docker Compose plugin |
| **kubectl** | Kubernetes CLI |
| **kind** | Kubernetes in Docker (local clusters) |
| **Helm** | Kubernetes package manager |
| **Terraform** | Infrastructure as Code |
| **AWS CLI v2** | Amazon Web Services CLI |
| **VS Code** | Editor (optional) |
| **minikube** | Alternative local K8s (optional) |
| **kubectx / kubens** | Fast context/namespace switching |
| **Git, curl, wget, htop** | Core utilities |

## Quick Start

```bash
# 1. Clone or download
git clone [it](https://github.com/asimayazmrd0987-glitch/Stoic.git)

# 1.2 Move to it 
cd Linux-Scripts

# 2. Make executable
chmod +x setup-devops.sh

# 3. Run
./setup-devops.sh
```

> **Note:** You will be prompted for `sudo` password during execution.

## What Happens During Install

1. **Detects your distro** automatically (Fedora, Ubuntu, Debian, Arch, Omarchy)
2. **Skips already-installed tools** — safe to re-run
3. **Adds official repositories** for Docker, HashiCorp, Microsoft
4. **Enables Docker service** and adds your user to the `docker` group
5. **Prints a summary** at the end showing what was installed

## Post-Install

```bash
# Log out and back in (or reboot) for Docker permissions
# Then verify everything:

docker run hello-world
kubectl version --client
kind version
terraform version
aws --version
```

## Create Your First K8s Cluster

```bash
# Single-node cluster (recommended for laptops with <16GB RAM)
cat > kind-config.yaml << 'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
EOF

kind create cluster --config kind-config.yaml
kubectl get nodes
```

## For Low-RAM Machines (8GB)

If your machine has 8GB RAM or less, run the included performance tuning script after setup:

```bash
chmod +x fedora-optimize.sh
./fedora-optimize.sh
```

This configures:
- `zram` (compressed swap in RAM)
- `earlyoom` (prevents OOM freezes)
- Higher `vm.swappiness`
- Disabled GNOME Tracker indexing

## Uninstall / Clean Up

The script does not provide an uninstaller. To remove tools, but don't do it buddy :

```bash
# Fedora
sudo dnf remove docker-ce kubectl terraform

# Ubuntu
sudo apt remove docker-ce kubectl terraform

# Arch
sudo pacman -R docker kubectl terraform
```

## Contributing

Pull requests welcome. Tested on:
- Fedora 44 Workstation
- Ubuntu 24.04 LTS
- Arch Linux (2025.06)

## License

MIT
