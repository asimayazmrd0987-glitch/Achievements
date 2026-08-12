#!/bin/bash
# Fedora Oh My Zsh + Powerlevel10k One-Click Installer
# Run: chmod +x setup-zsh.sh && ./setup-zsh.sh

set -e

echo "=========================================="
echo "  Fedora Zsh + Powerlevel10k Setup"
echo "=========================================="

# Step 1: Clean up broken configs
echo "[1/8] Cleaning up old configs..."
sed -i '/kubectl completion/d' ~/.zshrc 2>/dev/null || true
sed -i '/complete -o default -F __start_kubectl/d' ~/.zshrc 2>/dev/null || true
sed -i '/PROMPT=/d' ~/.zshrc 2>/dev/null || true
sed -i '/PS1=/d' ~/.zshrc 2>/dev/null || true
sed -i '/precmd/d' ~/.zshrc 2>/dev/null || true
sed -i '/vcs_info/d' ~/.zshrc 2>/dev/null || true
sed -i '/prompt_subst/d' ~/.zshrc 2>/dev/null || true
sed -i '/starship/d' ~/.zshrc 2>/dev/null || true
rm -f ~/.config/starship.toml

# Backup current zshrc if it exists
if [ -f ~/.zshrc ]; then
    cp ~/.zshrc ~/.zshrc.backup.$(date +%s)
    echo "  -> Backup created: ~/.zshrc.backup.*"
fi

# Step 2: Install dependencies
echo "[2/8] Installing zsh, git, curl, wget..."
sudo dnf install -y zsh git curl wget fontconfig

# Step 3: Install Oh My Zsh
echo "[3/8] Installing Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo "  -> Oh My Zsh already installed, skipping..."
fi

# Step 4: Install Powerlevel10k
echo "[4/8] Installing Powerlevel10k theme..."
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
else
    echo "  -> Powerlevel10k already installed, skipping..."
fi

# Set theme
sed -i 's/ZSH_THEME=".*"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc

# Step 5: Install plugins
echo "[5/8] Installing zsh plugins..."

# zsh-autosuggestions
if [ ! -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
else
    echo "  -> zsh-autosuggestions already installed, skipping..."
fi

# zsh-syntax-highlighting
if [ ! -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
else
    echo "  -> zsh-syntax-highlighting already installed, skipping..."
fi

# Update plugins list
sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc

# Step 6: Install MesloLGS Nerd Font
echo "[6/8] Installing MesloLGS Nerd Font..."
mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts

fonts=(
    "MesloLGS%20NF%20Regular.ttf"
    "MesloLGS%20NF%20Bold.ttf"
    "MesloLGS%20NF%20Italic.ttf"
    "MesloLGS%20NF%20Bold%20Italic.ttf"
)

names=(
    "MesloLGS NF Regular.ttf"
    "MesloLGS NF Bold.ttf"
    "MesloLGS NF Italic.ttf"
    "MesloLGS NF Bold Italic.ttf"
)

for i in "${!fonts[@]}"; do
    if [ ! -f "${names[$i]}" ]; then
        curl -fLo "${names[$i]}" "https://github.com/romkatv/powerlevel10k-media/raw/master/${fonts[$i]}"
    else
        echo "  -> ${names[$i]} already exists, skipping..."
    fi
done

fc-cache -fv

echo ""
echo "  !! IMPORTANT: Set your terminal font to 'MesloLGS NF' !!"
echo "     - GNOME Terminal: Preferences -> Profile -> Text -> Custom Font"
echo "     - VS Code: Settings -> Terminal › Integrated: Font Family -> MesloLGS NF"
echo ""

# Step 7: Add aliases and extras
echo "[7/8] Adding aliases and config..."

# Remove old aliases block if exists
sed -i '/# --- Mosh-style aliases ---/,/# --- Load Powerlevel10k config ---/d' ~/.zshrc 2>/dev/null || true

cat >> ~/.zshrc <<'EOF'

# --- Mosh-style aliases ---
alias c='clear'
alias ..='cd ..'
alias ...='cd ../..'
alias l='ls -lah'
alias ll='ls -lh'
alias mkdirp='mkdir -p'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'
alias gco='git checkout'
alias gcb='git checkout -b'

# --- kubectl aliases (only if installed) ---
if command -v kubectl &> /dev/null; then
  alias k='kubectl'
  alias kg='kubectl get'
  alias kd='kubectl describe'
  alias kdel='kubectl delete'
  alias ka='kubectl apply -f'
  alias kgp='kubectl get pods'
  alias kgs='kubectl get svc'
  alias kgn='kubectl get nodes'
fi

# --- Docker aliases ---
alias d='docker'
alias dc='docker compose'
alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias dex='docker exec -it'

# --- DSA / Dev aliases ---
alias g++='g++ -std=c++17 -Wall -Wextra'
alias g++d='g++ -std=c++17 -Wall -Wextra -g'
alias mk='make'
alias mkc='make clean'
alias mkr='make run'

# --- History ---
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS

# --- fzf integration ---
[ -f /usr/share/fzf/shell/key-bindings.zsh ] && source /usr/share/fzf/shell/key-bindings.zsh
[ -f /usr/share/fzf/shell/completion.zsh ] && source /usr/share/fzf/shell/completion.zsh

# --- Load Powerlevel10k config ---
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
EOF

# Step 8: Finalize
echo "[8/8] Finalizing..."

# Set zsh as default shell
if [ "$SHELL" != "$(which zsh)" ]; then
    chsh -s $(which zsh)
    echo "  -> Default shell changed to zsh. Log out and back in for full effect."
fi

# Source zshrc
echo "  -> Sourcing ~/.zshrc..."
source ~/.zshrc 2>/dev/null || true

echo ""
echo "=========================================="
echo "  Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Change your terminal font to 'MesloLGS NF'"
echo "  2. Run: p10k configure"
echo "  3. Log out and back in for shell change"
echo ""
echo "Run 'p10k configure' now to customize your prompt."
echo ""

# Offer to run p10k configure
read -p "Run p10k configure now? [Y/n]: " response
response=${response:-Y}
if [[ "$response" =~ ^[Yy]$ ]]; then
    p10k configure
fi
