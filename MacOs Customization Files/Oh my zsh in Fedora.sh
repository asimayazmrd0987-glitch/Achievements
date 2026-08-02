### Step 1
bash ,,,,
# Remove the broken kubectl completion line and any custom prompt stuff
sed -i '/kubectl completion/d' ~/.zshrc 2>/dev/null
sed -i '/complete -o default -F __start_kubectl/d' ~/.zshrc 2>/dev/null
sed -i '/PROMPT=/d' ~/.zshrc 2>/dev/null
sed -i '/PS1=/d' ~/.zshrc 2>/dev/null
sed -i '/precmd/d' ~/.zshrc 2>/dev/null
sed -i '/vcs_info/d' ~/.zshrc 2>/dev/null
sed -i '/prompt_subst/d' ~/.zshrc 2>/dev/null

# Remove any starship references
sed -i '/starship/d' ~/.zshrc 2>/dev/null
rm -f ~/.config/starship.toml

# Backup current zshrc
cp ~/.zshrc ~/.zshrc.backup.$(date +%s)
,,,,

### Step 2
Install Oh My Zsh
bash ,,,,
# Install zsh (if not already)
sudo dnf install -y zsh git curl wget

# Install Oh My Zsh (non-interactive)
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
,,,,

### Step 3
 Install Powerlevel10k Theme
bash ,,,,
# Clone Powerlevel10k into Oh My Zsh custom themes
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

# Set the theme in .zshrc
sed -i 's/ZSH_THEME=".*"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc
,,,,

### Step 4
Install Plugins Mosh Uses
bash ,,,,
# zsh-autosuggestions (greyed-out command suggestions)
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# zsh-syntax-highlighting (colored commands as you type)
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# Update plugins list in .zshrc
sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc
,,,,

### Step 5
 Install a Nerd Font (Required for Icons)
Powerlevel10k needs a Nerd Font to display the fancy icons. Mosh typically uses MesloLGS Nerd Font:
bash
# Create fonts directory
mkdir -p ~/.local/share/fonts

# Download MesloLGS Nerd Font
cd ~/.local/share/fonts
curl -fLo "MesloLGS NF Regular.ttf" https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf
curl -fLo "MesloLGS NF Bold.ttf" https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf
curl -fLo "MesloLGS NF Italic.ttf" https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf
curl -fLo "MesloLGS NF Bold Italic.ttf" https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf

# Refresh font cache
fc-cache -fv
Important: After this, open VS Code: → Settings → Terminal › Integrated: Font Family → Set to MesloLGS NF
Also set your GNOME Terminal / Tilix / Kitty font to MesloLGS NF for the icons to show properly.

### Step 6
Run the Powerlevel10k Configuration Wizard
bash
# Source the new config
source ~/.zshrc

# Run the wizard (this creates ~/.p10k.zsh)
p10k configure

### Step 7
Add Mosh-Style Aliases & Extras
Append these to ~/.zshrc:
bash
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

### Step 8
Final Setup & Test
bash
# Ensure zsh is default shell
chsh -s $(which zsh)

# Source everything
source ~/.zshrc

