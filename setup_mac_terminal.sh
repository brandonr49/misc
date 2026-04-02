#!/bin/bash
#
# Mac Full Setup Script
# Installs applications, configures macOS preferences, sets up terminal environment.
#
# Usage:
#   bash setup_mac.sh [OPTIONS]
#
# Options:
#   -h, --help          Show this help message
#   --hostname NAME     Set the Mac's hostname (HostName, LocalHostName, ComputerName)
#   --backup            Back up existing dotfiles before overwriting (off by default)
#
# If --hostname is not passed, edit HOSTNAME below before running.
# Leave empty to skip hostname configuration.
#
# IMPORTANT: Do NOT run with sudo. Run as your normal user.
#   Safe to re-run (idempotent).
#   After running, a reboot is recommended for all preferences to take effect.
#

# ── User-editable defaults ────────────────────────────────────────────────
HOSTNAME=""
BACKUP_DOTFILES=false
# ──────────────────────────────────────────────────────────────────────────

set -e

usage() {
    sed -n '2,/^$/{ s/^# \?//; p }' "$0"
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            ;;
        --hostname)
            HOSTNAME="$2"
            shift 2
            ;;
        --hostname=*)
            HOSTNAME="${1#*=}"
            shift
            ;;
        --backup)
            BACKUP_DOTFILES=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run with -h for usage."
            exit 1
            ;;
    esac
done

YELLOW='\033[1;33m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
RED='\033[1;31m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $1"; }
ok()    { echo -e "${GREEN}[ OK ]${NC}  $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $1"; }

section() {
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  $1${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}


########################################
# 0. Pre-flight checks
########################################
section "Pre-flight checks"

if [[ "$(uname)" != "Darwin" ]]; then
    fail "This script is for macOS only."
    exit 1
fi
ok "Running on macOS $(sw_vers -productVersion)"

# Detect laptop vs desktop (used for WiFi and other conditional settings)
IS_LAPTOP=false
if ioreg -l 2>/dev/null | grep -q "AppleSmartBattery"; then
    IS_LAPTOP=true
    ok "Hardware: laptop (battery detected)"
else
    ok "Hardware: desktop (no battery)"
fi

if [[ "$EUID" -eq 0 ]]; then
    fail "Do not run this script as root or with sudo."
    echo "     Homebrew refuses to install as root, and most of this script"
    echo "     should run as your normal user. Commands that need elevated"
    echo "     privileges will prompt for sudo individually."
    echo ""
    echo "     Run it like this:  bash ~/setup_mac.sh"
    exit 1
fi
ok "Running as user $(whoami)"

# Set up passwordless sudo so the script can run fully unattended.
# Creates a drop-in file in /etc/sudoers.d/ (doesn't touch main sudoers).
# Delete /etc/sudoers.d/<username> to revert.
SUDOERS_FILE="/etc/sudoers.d/$(whoami)"
if sudo -n true 2>/dev/null; then
    ok "Passwordless sudo already configured"
else
    info "Setting up passwordless sudo (will prompt for password one last time)..."
    echo "$(whoami) ALL=(ALL) NOPASSWD: ALL" | sudo tee "$SUDOERS_FILE" > /dev/null
    sudo chmod 0440 "$SUDOERS_FILE"
    ok "Passwordless sudo configured via $SUDOERS_FILE"
fi

# Track issues for the summary
MANUAL_STEPS=()
FAILED_CASKS=()

########################################
# 1. Hostname
########################################
if [ -n "$HOSTNAME" ]; then
    section "Hostname"
    info "Setting hostname to: $HOSTNAME"
    sudo scutil --set HostName "$HOSTNAME"
    sudo scutil --set LocalHostName "$HOSTNAME"
    sudo scutil --set ComputerName "$HOSTNAME"
    sudo dscacheutil -flushcache
    ok "Hostname set to $HOSTNAME (HostName + LocalHostName + ComputerName)"
fi

########################################
# 2. Xcode Command Line Tools
########################################
section "Xcode Command Line Tools"

if xcode-select -p &>/dev/null; then
    ok "Xcode Command Line Tools already installed"
else
    info "Installing Xcode Command Line Tools..."
    xcode-select --install 2>/dev/null || true
    info "Waiting for Xcode CLT installation (this may take a few minutes)..."
    until xcode-select -p &>/dev/null; do
        sleep 10
    done
    ok "Xcode Command Line Tools installed"
fi

########################################
# 2. Homebrew
########################################
section "Homebrew"

if ! command -v brew &>/dev/null; then
    info "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    ok "Homebrew already installed"
fi

# Ensure brew is on PATH for this script (Apple Silicon + Intel)
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"

# Full update so cask checksums and URLs are current.
# This is the #1 fix for "checksum mismatch" and "purged old cask" errors.
info "Updating Homebrew (ensures cask checksums are current)..."
brew update
info "Cleaning stale downloads (prevents checksum mismatches on re-runs)..."
brew cleanup --prune=all 2>/dev/null || true
ok "Homebrew ready"

########################################
# 3. CLI tools
########################################
section "CLI tools"

CLI_TOOLS=(
    git
    vim
    tree
    dockutil
    mas
    mysides       # Finder sidebar management
    node
    python
    ffmpeg
    whisper-cpp
    bitwarden-cli
    displayplacer     # CLI display resolution/arrangement config
    neovim
    gh                # GitHub CLI
    tea               # Gitea CLI
    zsh-autosuggestions
    zsh-syntax-highlighting
)

for tool in "${CLI_TOOLS[@]}"; do
    if brew list "$tool" &>/dev/null; then
        ok "$tool already installed"
    else
        info "Installing $tool..."
        brew install "$tool" 2>/dev/null || warn "Failed to install $tool"
    fi
done
ok "CLI tools installed"

# Claude Code (requires node, installed above)
if command -v claude &>/dev/null; then
    ok "Claude Code already installed"
else
    info "Installing Claude Code via npm..."
    npm install -g @anthropic-ai/claude-code 2>/dev/null || warn "Failed to install Claude Code"
fi

########################################
# 4. Dotfiles — backup
########################################
section "Dotfiles"

if $BACKUP_DOTFILES; then
    BACKUP_DIR=~/dotfiles_backup_$(date +%Y%m%d_%H%M%S)
    NEEDS_BACKUP=false
    for f in ~/.zshrc ~/.zsh_alias ~/.zsh_ps1 ~/.vim/.vimrc ~/.gitconfig; do
        [ -f "$f" ] && NEEDS_BACKUP=true && break
    done
    if $NEEDS_BACKUP; then
        info "Backing up existing dotfiles to $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
        for f in ~/.zshrc ~/.zsh_alias ~/.zsh_ps1 ~/.vim/.vimrc ~/.gitconfig; do
            [ -f "$f" ] && cp "$f" "$BACKUP_DIR/" 2>/dev/null || true
        done
        ok "Backup complete → $BACKUP_DIR"
    fi
else
    ok "Dotfile backup skipped (use --backup to enable)"
fi

########################################
# 5. ~/.zsh_alias
########################################
info "Writing ~/.zsh_alias"
cat > ~/.zsh_alias << 'ALIAS_EOF'
####################################################################################################
# cd up a directory
alias ..="cd ../"
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."

####################################################################################################
# ls (macOS compatible)
alias l="ls -lhtrG"
alias ls="ls -lhtrG"
alias la="ls -laG"

####################################################################################################
# misc
alias df='df -h'
alias zshrc='vim ~/.zshrc'

####################################################################################################
# git
alias gc="git commit"
alias gca="git commit --amend"
alias gb="git branch"
alias gco="git checkout"
alias go="git checkout"
alias gd="git diff"
alias gdc="git diff --cached"
alias ga="git add"
alias gaa="git add ."
alias gf="git fetch"
alias gl="git lola"
alias glog="git log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --"
alias gs="git status"
alias gbl="git blame"
alias gt="git tag"
alias gh="git stash"
alias ghp="git stash pop"
alias gg="git grep -i"
alias gri="git rebase -i"
alias gps="git push"
alias gpl="git pull"
alias pull="git pull"
alias push="git push"

####################################################################################################
# Military Time
alias date='date "+%a %b %d %H:%M:%S %Z %Y"'

####################################################################################################
# macOS specific
alias showfiles="defaults write com.apple.finder AppleShowAllFiles YES; killall Finder"
alias hidefiles="defaults write com.apple.finder AppleShowAllFiles NO; killall Finder"
alias flushdns="sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder"
ALIAS_EOF
ok "~/.zsh_alias written"

########################################
# 6. ~/.zsh_ps1
########################################
info "Writing ~/.zsh_ps1"
cat > ~/.zsh_ps1 << 'PS1_EOF'
COLOR1="%F{33}"   # blue - username (works in Terminal.app + iTerm2)
COLOR2="%F{46}"   # green - hostname
COLOR4="%F{214}"  # orange - git branch
WHITE="%F{15}"    # bright white

function git_branch_name()
{
  branch=$(git symbolic-ref HEAD 2> /dev/null | awk 'BEGIN{FS="/"} {print $NF}')
  if [[ $branch == "" ]]; then
    :
  else
    echo ' - ('$branch')'
  fi
}

setopt PROMPT_SUBST
export PS1="${WHITE}[${COLOR1}%n${WHITE}@${COLOR2}%m${WHITE}:%(4~|.../%3~|%~)]${COLOR4}\$(git_branch_name)${WHITE}%# "
PS1_EOF
ok "~/.zsh_ps1 written"

########################################
# 7. ~/.zshrc
########################################
info "Writing ~/.zshrc"
cat > ~/.zshrc << 'ZSHRC_EOF'
autoload -U compinit
compinit

setopt nonomatch
setopt COMPLETE_IN_WORD
setopt NO_BEEP

####################################################################################################
# History
####################################################################################################
export HISTFILE=~/.zsh_history
export HISTSIZE=10000000
export SAVEHIST=10000000
export HISTTIMEFORMAT="[%F %T] "

setopt INC_APPEND_HISTORY_TIME
setopt EXTENDED_HISTORY
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_SAVE_NO_DUPS
setopt interactive_comments

####################################################################################################
# Key bindings — vi mode with bash shortcuts
####################################################################################################
bindkey -v
bindkey '^R' history-incremental-search-backward
bindkey '^A' beginning-of-line
bindkey '^E' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[H'  beginning-of-line
bindkey '^[[F'  end-of-line
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word
bindkey "^[f" forward-word
bindkey "^[b" backward-word

####################################################################################################
# Environment
####################################################################################################
export EDITOR=vim
export TIMEFMT=$'\n================\nCPU\t%P\nuser\t%*U\nsystem\t%*S\ntotal\t%*E'

precmd () {print -Pn "\e]0;%~\a"};
source ~/.zsh_ps1
source ~/.zsh_alias

####################################################################################################
# Homebrew PATH
####################################################################################################
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"

####################################################################################################
# Python venv (/opt/brobpy)
####################################################################################################
if [ -f /opt/brobpy/bin/activate ]; then
  source /opt/brobpy/bin/activate
fi

####################################################################################################
# User customization (not clobbered by re-running setup)
####################################################################################################
[ -f ~/.zsh_user_custom ] && source ~/.zsh_user_custom

####################################################################################################
# Zsh plugins (Homebrew)
####################################################################################################
BREW_PREFIX="$(brew --prefix 2>/dev/null)"
if [ -n "$BREW_PREFIX" ]; then
    [ -f "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ] && \
        source "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    [ -f "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] && \
        source "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
ZSH_HIGHLIGHT_STYLES[comment]=fg=245
ZSHRC_EOF
ok "~/.zshrc written"

########################################
# 8. Vim
########################################
section "Vim"

mkdir -p ~/.vim/bundle
if [ ! -d ~/.vim/bundle/Vundle.vim ]; then
    info "Cloning Vundle..."
    git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
fi

cat > ~/.vim/.vimrc << 'VIMRC_EOF'
if v:lang =~ "utf8$" || v:lang =~ "UTF-8$"
   set fileencodings=ucs-bom,utf-8,latin1
endif

set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
Plugin 'gmarik/Vundle.vim'
Plugin 'ervandew/supertab'
Plugin 'scrooloose/nerdtree'
Plugin 'morhetz/gruvbox'
Plugin 'kien/ctrlp.vim'
call vundle#end()

let g:ctrlp_show_hidden = 1

set nocompatible
set bs=indent,eol,start
set viminfo='20,"50
set history=50
set ruler
set directory=/tmp

if has("autocmd")
  augroup jumpback
  autocmd!
  autocmd BufReadPost *
  \ if line("'\"") > 0 && line ("'\"") <= line("$") |
  \   exe "normal! g'\"" |
  \ endif
  augroup END
endif

if &t_Co > 2 || has("gui_running")
  syntax on
  set hlsearch
endif

filetype plugin indent on
syntax enable
let mapleader=","

" Appearance
set t_Co=256
set background=dark
silent! colorscheme gruvbox
set nu
set hlsearch

" Indentation
set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab
set backspace=indent,eol,start

" Mouse / trackpad — scroll and click inside vim
set mouse=a
if has('mouse_sgr')
  set ttymouse=sgr
elseif !has('nvim')
  set ttymouse=xterm2
endif

" Disable bell completely
set noerrorbells
set visualbell
set t_vb=
if has('autocmd')
  autocmd GUIEnter * set vb t_vb=
endif

" SuperTab
let g:SuperTabDefaultCompletionType = "context"
let g:SuperTabCrMapping=1
VIMRC_EOF

ln -sf ~/.vim/.vimrc ~/.vimrc
info "Installing Vim plugins..."
vim +PluginInstall +qall 2>/dev/null
ok "Vim configured"

########################################
# 9. Git
########################################
section "Git"

DIFF_HIGHLIGHT=""
for candidate in \
    "$(brew --prefix git 2>/dev/null)/share/git-core/contrib/diff-highlight/diff-highlight" \
    "/opt/homebrew/share/git-core/contrib/diff-highlight/diff-highlight" \
    "/usr/local/share/git-core/contrib/diff-highlight/diff-highlight"; do
    [ -f "$candidate" ] && DIFF_HIGHLIGHT="$candidate" && break
done
[ -n "$DIFF_HIGHLIGHT" ] && chmod +x "$DIFF_HIGHLIGHT" 2>/dev/null || true

EXISTING_NAME=$(git config --global user.name 2>/dev/null || echo "")
EXISTING_EMAIL=$(git config --global user.email 2>/dev/null || echo "")

cat > ~/.gitconfig << GITCONFIG_EOF
[user]
  name = ${EXISTING_NAME:-YOUR_NAME}
  email = ${EXISTING_EMAIL:-YOUR_EMAIL}

[filter "lfs"]
  clean = git-lfs clean -- %f
  smudge = git-lfs smudge -- %f
  process = git-lfs filter-process
  required = true

[color]
  ui = auto

[color "branch"]
  current = yellow reverse
  local = green
  remote = blue

[color "diff"]
  meta = white
  frag = magenta bold
  old = red
  new = green
  colorMoved = default

[color "status"]
  added = green
  changed = blue
  untracked = yellow
  deleted = red

[core]
  excludesfile = ~/.config/git/ignore
  editor = vim
$([ -n "$DIFF_HIGHLIGHT" ] && echo "  pager = $DIFF_HIGHLIGHT | less" || echo "  pager = less")

[alias]
  co = checkout
  cam = commit -am
  ci = commit
  st = status
  br = branch
  f = fetch --all
  fp = fetch --all --prune
  df = diff --word-diff
  hist = log --pretty=format:"%h %ad | %s%d [%an]" --graph --date=short
  last = cat-file commit HEAD
  l = log --pretty=format:'%h %ad  %s%x09%ae' --date=short
  type = cat-file -t
  dump = cat-file -p
  lol = log --graph --decorate --pretty=oneline --abbrev-commit
  lola = log --graph --decorate --pretty=oneline --abbrev-commit --all
  dag = log --graph --format='format:%C(yellow)%h%C(reset) %C(blue)\"%an\" <%ae>%C(reset) %C(magenta)%ar%C(reset)%C(auto)%d%C(reset)%n%s' --date-order

[init]
  defaultBranch = main

[pull]
  rebase = false

[push]
  default = current
  autoSetupRemote = true

[apply]
  whitespace = fix

[rerere]
  enabled = true

[rebase]
  autosquash = true

[credential]
  helper = osxkeychain

$([ -n "$DIFF_HIGHLIGHT" ] && cat << INTERACTIVE_EOF
[interactive]
  difffilter = $DIFF_HIGHLIGHT
INTERACTIVE_EOF
)

[diff]
  wordRegex = .
  compactionHeuristic = true
  algorithm = patience

[merge]
  conflictstyle = diff3
GITCONFIG_EOF
ok "~/.gitconfig written"

mkdir -p ~/.config/git
cat > ~/.config/git/ignore << 'IGNORE_EOF'
.DS_Store
*.swp
*.swo
*~
.idea/
.vscode/
__pycache__/
*.pyc
.env
IGNORE_EOF
ok "~/.config/git/ignore written"

########################################
# 10. Python venv (/opt/brobpy)
########################################
section "Python venv"

if [ -d /opt/brobpy ]; then
    ok "Python venv already exists at /opt/brobpy"
else
    info "Creating Python venv at /opt/brobpy..."
    sudo mkdir -p /opt/brobpy
    sudo chown "$(whoami)" /opt/brobpy
    python3 -m venv /opt/brobpy
    ok "Python venv created at /opt/brobpy"
    info "Upgrading pip..."
    /opt/brobpy/bin/pip install --upgrade pip 2>/dev/null || true
fi

########################################
# 11. macOS Preferences
########################################
section "macOS Preferences"


# ── Animations ─────────────────────────────────────────────────────────────
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
sudo defaults write com.apple.universalaccess reduceMotion -bool true
defaults write com.apple.dock autohide-time-modifier -float 0
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock launchanim -bool false
defaults write com.apple.dock expose-animation-duration -float 0.1
defaults write com.apple.finder DisableAllAnimations -bool true
defaults write com.apple.dock missioncontrol-animation-duration -float 0.1
defaults write NSGlobalDomain NSScrollAnimationEnabled -bool false
defaults write -g QLPanelAnimationDuration -float 0
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
defaults write NSGlobalDomain com.apple.springing.delay -float 0
defaults write com.apple.dock mineffect -string "scale"
defaults write com.apple.finder AnimateInfoPanes -bool false
ok "Animations disabled"

# ── Window tiling ──────────────────────────────────────────────────────────
defaults write com.apple.WindowManager EnableTiledWindowMargins -bool false
ok "Tiling margins disabled"

# ── Finder ─────────────────────────────────────────────────────────────────
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
defaults write com.apple.finder NewWindowTarget -string "PfHm"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/"
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
defaults write com.apple.finder WarnOnEmptyTrash -bool false
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
defaults write NSGlobalDomain com.apple.springing.enabled -bool true
ok "Finder preferences set"

# ── Finder sidebar ────────────────────────────────────────────────────────
if command -v mysides &>/dev/null; then
    # Remove unwanted sidebar items
    mysides remove Recents 2>/dev/null || true
    mysides remove Tags 2>/dev/null || true
    mysides remove "iCloud Drive" 2>/dev/null || true
    # Add home directory
    mysides add "$(whoami)" "file://$HOME/" 2>/dev/null || true
    ok "Finder sidebar configured"
else
    warn "mysides not available — sidebar items not modified"
fi

# Disable iCloud Drive (comment out if you use iCloud)
defaults write com.apple.finder FXICloudDriveEnabled -bool false 2>/dev/null || true
defaults write com.apple.finder FXICloudDriveDesktop -bool false 2>/dev/null || true
defaults write com.apple.finder FXICloudDriveDocuments -bool false 2>/dev/null || true

# Remove tags from sidebar
defaults write com.apple.finder ShowRecentTags -bool false

ok "iCloud Drive and tags disabled"

# ── Network (uncomment as needed) ─────────────────────────────────────────
# Turn off WiFi on desktops (laptops keep WiFi on)
if ! $IS_LAPTOP; then
    networksetup -setairportpower en0 off 2>/dev/null || \
    networksetup -setairportpower Wi-Fi off 2>/dev/null || true
    ok "WiFi disabled (desktop)"
else
    ok "WiFi left on (laptop detected)"
fi

# Set a static IP (edit values, uncomment to use)
# STATIC_IP="192.168.1.100"
# SUBNET="255.255.255.0"
# ROUTER="192.168.1.1"
# DNS="8.8.8.8 8.8.4.4"
# networksetup -setmanual "Ethernet" "$STATIC_IP" "$SUBNET" "$ROUTER"
# networksetup -setdnsservers "Ethernet" $DNS

# ── Keyboard ───────────────────────────────────────────────────────────────
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3
ok "Keyboard preferences set"

# ── Trackpad ───────────────────────────────────────────────────────────────
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.trackpad.scaling -float 2.0
ok "Trackpad preferences set"

# ── Mouse ──────────────────────────────────────────────────────────────────
# Mouse tracking speed: 0.0 (slow) to 3.0 (fast). 7/10 = 2.1
defaults write NSGlobalDomain com.apple.mouse.scaling -float 2.1
ok "Mouse tracking speed set (7/10)"

# ── Dock ───────────────────────────────────────────────────────────────────
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock tilesize -int 48
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock minimize-to-application -bool true
ok "Dock behavior set"

# ── Screenshots ────────────────────────────────────────────────────────────
mkdir -p "${HOME}/Screenshots"
defaults write com.apple.screencapture location -string "${HOME}/Screenshots"
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true
ok "Screenshots set"

# ── Dialogs ────────────────────────────────────────────────────────────────
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true
ok "Dialogs set"

# ── Menu Bar ──────────────────────────────────────────────────────────────
defaults write com.apple.menuextra.clock Show24Hour -bool true
defaults write com.apple.menuextra.battery ShowPercent -string "YES"
ok "Menu bar set"

# ── Sound — disable all system beeps/bonks ────────────────────────────────
defaults write NSGlobalDomain com.apple.sound.uiaudio.enabled -int 0
defaults write NSGlobalDomain com.apple.sound.beep.volume -float 0.0
ok "System sounds disabled"

# ── Security ──────────────────────────────────────────────────────────────
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0
ok "Security set"

# ── SSH (Remote Login) ────────────────────────────────────────────────────
sudo systemsetup -setremotelogin on 2>/dev/null || true
ok "SSH enabled (Remote Login on)"

# ── Misc ──────────────────────────────────────────────────────────────────
defaults write com.apple.LaunchServices LSQuarantine -bool false
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain NSDisableAutomaticTermination -bool true
defaults write com.apple.systempreferences NSQuitAlwaysKeepsWindows -bool false
defaults write com.apple.finder QLEnableTextSelection -bool true
ok "Misc set"

# ── Widgets / Notification Center ─────────────────────────────────────────
# Disable desktop widgets
defaults write com.apple.WindowManager StandardHideDesktopIcons -bool true 2>/dev/null || true
defaults write com.apple.WindowManager HideDesktop -bool true 2>/dev/null || true

# Disable widget suggestions
defaults write com.apple.widgets widgetSuggestions -bool false 2>/dev/null || true

# Disable Notification Center (may not fully work on Sequoia+ due to SIP)
launchctl unload -w /System/Library/LaunchAgents/com.apple.notificationcenterui.plist 2>/dev/null || true

# Disable all app notifications by default
defaults write com.apple.notificationcenterui showWidgets -bool false 2>/dev/null || true

ok "Widgets and Notification Center disabled"

# ── iTerm2 ────────────────────────────────────────────────────────────────
defaults write com.googlecode.iterm2 "Silence bell" -bool true 2>/dev/null || true
# Set default profile background to black (RGB 0,0,0)
/usr/libexec/PlistBuddy -c "Set ':New Bookmarks:0:Background Color:Red Component' 0.0" \
    ~/Library/Preferences/com.googlecode.iterm2.plist 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set ':New Bookmarks:0:Background Color:Green Component' 0.0" \
    ~/Library/Preferences/com.googlecode.iterm2.plist 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set ':New Bookmarks:0:Background Color:Blue Component' 0.0" \
    ~/Library/Preferences/com.googlecode.iterm2.plist 2>/dev/null || true
ok "iTerm2 bell silenced + background set to black"

# ── Apply ─────────────────────────────────────────────────────────────────
info "Restarting affected services..."
for svc in Finder Dock SystemUIServer; do
    killall "$svc" 2>/dev/null || true
done
ok "Preferences applied (some need logout/reboot)"

########################################
# 11. Remove default bloat
########################################
section "Removing bloat applications"


for app in GarageBand iMovie Keynote Pages Numbers; do
    if [ -d "/Applications/$app.app" ]; then
        info "Removing $app..."
        sudo rm -rf "/Applications/$app.app" 2>/dev/null && ok "Removed $app" || warn "Could not remove $app"
    else
        ok "$app already removed"
    fi
done

########################################
# 12. GUI Applications (brew cask)
########################################
section "GUI Applications (brew cask)"


# Prevent brew from auto-updating between each cask install.
# We already did brew update — re-updating 30 times wastes minutes
# and is the main reason sudo credentials expire mid-run.
export HOMEBREW_NO_AUTO_UPDATE=1

CASK_APPS=(
    # Browsers
    google-chrome
    firefox

    # Communication
    discord
    slack
    zulip

    # Development
    android-studio
    visual-studio-code
    docker
    iterm2
    fork
    gitup-app
    github

    # AI / LLM
    claude
    ollama

    # Media
    jellyfin-media-player
    grayjay
    spotify
    vlc

    # Networking / VPN
    tailscale
    openvpn-connect
    microsoft-remote-desktop

    # Utilities
    bettertouchtool
    raycast
    karabiner-elements
    keepingyouawake
    appcleaner
    the-unarchiver
    grandperspective
    stats
    bitwarden
    forklift          # dual-pane file manager with SFTP/SMB/NFS/S3
    cyberduck         # free network file browser (SFTP/S3/WebDAV)
    radio-silence     # outbound firewall — block apps from phoning home
    maccy             # clipboard history manager (Cmd+Shift+C)

    # Gaming / Creative
    steam
    godot             # game engine
    aseprite          # pixel art / sprite editor

    # Virtualization
    utm

    # Window management / Spaces — PICK ONE, uncomment when you've decided:
    # AeroSpace: i3-like tiling WM, no SIP disable, TOML config, virtual workspaces
    #   brew install --cask nikitabobko/tap/aerospace
    # yabai + skhd: more mature tiling WM, some features need SIP disabled
    #   brew install koekeishiya/formulae/yabai koekeishiya/formulae/skhd
    # BetterTouchTool (already installed above) also has window snapping features
    # macOS native tiling (Sequoia+) is configured in the preferences section above
)

for app in "${CASK_APPS[@]}"; do
    if brew list --cask "$app" &>/dev/null; then
        ok "$app already installed (via brew)"
    else
        info "Installing $app..."
        OUTPUT=$(brew install --cask "$app" 2>&1) && {
            ok "$app installed"
        } || {
            if echo "$OUTPUT" | grep -qi "already exists"; then
                ok "$app already installed (not via brew — skipping)"
            else
                echo "$OUTPUT" | tail -3
                warn "Failed to install $app"
                FAILED_CASKS+=("$app")
            fi
        }
    fi
done

unset HOMEBREW_NO_AUTO_UPDATE

if [ ${#FAILED_CASKS[@]} -gt 0 ]; then
    echo ""
    warn "Failed casks: ${FAILED_CASKS[*]}"
    warn "Retry: brew update && brew cleanup && brew install --cask <name>"
    MANUAL_STEPS+=("Retry failed casks: ${FAILED_CASKS[*]}")
fi
ok "GUI app installs complete"

########################################
# 13. Dock layout (re-run after installs)
########################################
section "Dock layout"

if command -v dockutil &>/dev/null; then
    dockutil --remove all --no-restart 2>/dev/null || true

    for app in \
        "/Applications/Firefox.app" \
        "/Applications/Google Chrome.app" \
        "/Applications/Discord.app" \
        "/Applications/Slack.app" \
        "/Applications/Zulip.app" \
        "/Applications/iTerm.app" \
        "/Applications/Visual Studio Code.app" \
        "/Applications/Claude.app" \
        "/Applications/Android Studio.app" \
        "/Applications/Fork.app" \
        "/Applications/GitHub Desktop.app" \
        "/Applications/Spotify.app" \
        "/Applications/Jellyfin Media Player.app" \
        "/Applications/Grayjay.app" \
        "/Applications/VLC.app" \
        "/Applications/Steam.app" \
        "/Applications/Bitwarden.app" \
        "/Applications/ForkLift.app" \
        "/Applications/OpenVPN Connect.app" \
        "/Applications/Microsoft Remote Desktop.app" \
        "/Applications/UTM.app"; do
        [ -d "$app" ] && dockutil --add "$app" --no-restart 2>/dev/null || true
    done

    killall Dock 2>/dev/null || true
    ok "Dock layout set"
else
    warn "dockutil not found — configure Dock manually"
fi

########################################
# 14. Browser extensions
########################################
section "Browser extensions"

# ── Firefox extensions (via policies.json) ─────────────────────────────────
# policies.json is dropped into the Firefox app bundle's distribution/ folder.
# Firefox reads it on startup and auto-installs the listed extensions.
# NOTE: This file is overwritten on Firefox updates — the script re-creates it on re-run.
FIREFOX_DIST="/Applications/Firefox.app/Contents/Resources/distribution"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
POLICIES_SRC="$SCRIPT_DIR/config/firefox_policies.json"

if [ -d "/Applications/Firefox.app" ]; then
    sudo mkdir -p "$FIREFOX_DIST"
    if [ -f "$POLICIES_SRC" ]; then
        sudo cp "$POLICIES_SRC" "$FIREFOX_DIST/policies.json"
        ok "Firefox policies.json installed (uBlock Origin, Bitwarden, OneTab)"
    else
        warn "config/firefox_policies.json not found — place it next to setup_mac.sh"
        MANUAL_STEPS+=("Copy config/firefox_policies.json next to setup_mac.sh and re-run")
    fi
else
    warn "Firefox not installed yet — will install extensions on next run"
fi

# Note: Claude extension is Chrome-only — no Firefox version available

# ── Chrome extensions (via managed preferences) ───────────────────────────
# Chrome reads ExtensionSettings from managed preferences plist.
# This may not work on all macOS versions without MDM — worst case is a no-op.
CHROME_MANAGED="/Library/Managed Preferences"
if [ -d "/Applications/Google Chrome.app" ]; then
    sudo mkdir -p "$CHROME_MANAGED"
    sudo defaults write "$CHROME_MANAGED/com.google.Chrome" ExtensionSettings '{
        "ddkjiahejlhfcafbddmgiahcphecmpfh" = {
            "installation_mode" = "normal_installed";
            "update_url" = "https://clients2.google.com/service/update2/crx";
        };
        "nngceckbapebfimnlniiiahkandclblb" = {
            "installation_mode" = "normal_installed";
            "update_url" = "https://clients2.google.com/service/update2/crx";
        };
        "chphlpgkkbolifaimnlloiipkdnihall" = {
            "installation_mode" = "normal_installed";
            "update_url" = "https://clients2.google.com/service/update2/crx";
        };
        "fcoeoabgfenejglbffodgkkbkcdhcgfn" = {
            "installation_mode" = "normal_installed";
            "update_url" = "https://clients2.google.com/service/update2/crx";
        };
    }'
    # Also disable Chrome's built-in password manager (use Bitwarden instead)
    sudo defaults write "$CHROME_MANAGED/com.google.Chrome" PasswordManagerEnabled -bool false
    ok "Chrome managed prefs written (uBlock Origin Lite, Bitwarden, OneTab, Claude)"
    warn "Chrome managed extensions may not load without MDM — check chrome://policy"
else
    warn "Chrome not installed yet — will configure extensions on next run"
fi

# ── Set Firefox as default browser ────────────────────────────────────────
if [ -d "/Applications/Firefox.app" ]; then
    info "Setting Firefox as default browser..."
    open -a Firefox --args --setDefaultBrowser 2>/dev/null || \
    warn "Could not set Firefox as default — set manually in System Settings > Default Browser"
fi

########################################
# 15. Disable auto-launch and auto-update bloat
########################################
section "Disabling auto-launch and auto-update bloat"

# ── Microsoft Auto-Update — aggressively remove ──────────────────────────
MAU_PATHS=(
    "/Library/Application Support/Microsoft/MAU2.0"
    "$HOME/Library/LaunchAgents/com.microsoft.update.agent.plist"
)
for mau in "${MAU_PATHS[@]}"; do
    [ -e "$mau" ] && sudo rm -rf "$mau" 2>/dev/null && info "Removed $mau"
done
defaults write com.microsoft.autoupdate2 HowToCheck -string "Manual" 2>/dev/null || true
# Prevent MAU from re-installing via a launch daemon
sudo launchctl bootout system /Library/LaunchDaemons/com.microsoft.autoupdate.helper.plist 2>/dev/null || true
ok "Microsoft Auto-Update disabled"

# ── Disable auto-launch for common apps ──────────────────────────────────
# Spotify
defaults write com.spotify.client AutoStartSettingIsHidden -bool false 2>/dev/null || true
defaults write com.spotify.client LoginAutomationMode -string "off" 2>/dev/null || true

# Docker Desktop
defaults write com.docker.docker SUAutomaticallyCheckForUpdates -bool false 2>/dev/null || true
mkdir -p "$HOME/.docker"
if [ -f "$HOME/.docker/daemon.json" ]; then
    # Don't clobber existing docker config
    :
else
    echo '{}' > "$HOME/.docker/daemon.json"
fi

# Steam
defaults write com.valvesoftware.steam AutoLoginUser -string "" 2>/dev/null || true

# Slack
defaults write com.tinyspeck.slackmacgap SlackLaunchOnLogin -bool false 2>/dev/null || true

# Discord
defaults write com.hnc.Discord OPEN_ON_STARTUP -bool false 2>/dev/null || true

# Remove all user login items added by apps (reset to clean)
# This is aggressive — comment out if you have login items you want to keep
# osascript -e 'tell application "System Events" to delete every login item' 2>/dev/null || true

ok "Auto-launch disabled for major apps"

# ── KeepingYouAwake — auto-start at login (menu bar app) ─────────────────
if [ -d "/Applications/KeepingYouAwake.app" ]; then
    osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/KeepingYouAwake.app", hidden:false}' 2>/dev/null || true
    open -a KeepingYouAwake 2>/dev/null || true
    ok "KeepingYouAwake added to login items + launched"
fi

# ── Maccy — auto-start at login (clipboard history, menu bar) ────────────
if [ -d "/Applications/Maccy.app" ]; then
    osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Maccy.app", hidden:false}' 2>/dev/null || true
    defaults write org.p0deje.Maccy hideTitle -bool true 2>/dev/null || true
    open -a Maccy 2>/dev/null || true
    ok "Maccy added to login items + launched (Cmd+Shift+C)"
fi

# ── BetterTouchTool — invert scroll for mice only ────────────────────────
# Keeps macOS natural scrolling ON for trackpads, inverts for normal mice.
# This is BTT's built-in per-device scroll inversion.
defaults write com.hegenberg.BetterTouchTool BTTReverseScrollingOnNormalMice -bool true 2>/dev/null || true
ok "BTT: mouse scroll inversion enabled (trackpad unchanged)"

########################################
# 16. Xcode IDE
########################################
section "Xcode IDE"


if [ -d "/Applications/Xcode.app" ]; then
    ok "Xcode already installed"
else
    if command -v mas &>/dev/null; then
        # Note: mas account is broken on newer macOS — just try the install directly.
        # If not signed into App Store, mas will fail with a clear error.
        info "Installing Xcode via Mac App Store (~13GB, may take a while)..."
        mas install 497799835 2>&1 || {
            warn "Xcode install via mas failed (sign into App Store first?)"
            MANUAL_STEPS+=("Install Xcode: open App Store, sign in, then run 'mas install 497799835'")
        }
    else
        warn "mas not available"
        MANUAL_STEPS+=("Install Xcode from the Mac App Store")
    fi
fi

if [ -d "/Applications/Xcode.app" ]; then
    sudo xcodebuild -license accept 2>/dev/null || true
    sudo xcodebuild -runFirstLaunch 2>/dev/null || true
    ok "Xcode license accepted"
fi

########################################
# 15. Mac App Store apps
########################################
section "Mac App Store apps"

if command -v mas &>/dev/null; then
    # MX Player — App Store ID 1579641008
    if mas list 2>/dev/null | grep -q "1579641008"; then
        ok "MX Player already installed"
    else
        info "Installing MX Player from App Store..."
        mas install 1579641008 2>&1 || warn "MX Player install failed (sign into App Store first?)"
    fi
else
    warn "mas not available — install MX Player manually from the App Store"
fi

########################################
# 16. Manual-download apps
########################################
section "Manual-download apps"

# AirCaption — no brew cask, download from website
if [ -d "/Applications/AirCaption.app" ]; then
    ok "AirCaption already installed"
else
    info "Opening AirCaption download page..."
    open "https://www.aircaption.com/download" 2>/dev/null || true
    MANUAL_STEPS+=("AirCaption: download and install from https://www.aircaption.com/download")
    warn "AirCaption must be downloaded manually — opened download page in browser"
fi

########################################
# 17. Desktop background — solid black
########################################
section "Desktop background"

info "Setting desktop background to solid black..."
osascript -e 'tell application "Finder" to set desktop picture to POSIX file "/System/Library/Desktop Pictures/Solid Colors/Black.png"' 2>/dev/null || \
osascript -e 'tell application "System Events" to tell every desktop to set picture to "/System/Library/Desktop Pictures/Solid Colors/Black.png"' 2>/dev/null || \
warn "Could not set desktop background automatically"
ok "Desktop background set to black"

########################################
# 18. Display — "More Space" resolution
########################################
section "Display resolution"

if command -v displayplacer &>/dev/null; then
    info "Setting all displays to 'More Space' (highest scaled resolution)..."
    # For each display, find the highest-resolution mode with scaling:on
    # and apply it. This is what macOS calls "More Space" in System Settings.
    displayplacer list 2>/dev/null | grep -E "^  mode" | while IFS= read -r line; do
        : # just parsing — actual config below
    done

    # Get display IDs and their highest scaled mode
    DISPLAY_IDS=$(displayplacer list 2>/dev/null | grep "Persistent screen id:" | awk '{print $NF}')
    for DISP_ID in $DISPLAY_IDS; do
        # Find the highest mode number with scaling:on for this display
        HIGHEST_MODE=$(displayplacer list 2>/dev/null | \
            awk "/Persistent screen id: $DISP_ID/,/^$/" | \
            grep "scaling:on" | \
            tail -1 | \
            grep -o "mode [0-9]*" | \
            awk '{print $2}')
        if [ -n "$HIGHEST_MODE" ]; then
            info "Display $DISP_ID → mode $HIGHEST_MODE"
            displayplacer "id:$DISP_ID mode:$HIGHEST_MODE" 2>/dev/null || true
        fi
    done
    ok "Displays set to More Space"
else
    warn "displayplacer not installed — set display to 'More Space' manually in System Settings > Displays"
fi

########################################
# 18. BetterTouchTool preset
########################################
section "BetterTouchTool preset"

BTT_PRESET="$SCRIPT_DIR/config/btt_preset.bttpreset"
if [ -f "$BTT_PRESET" ]; then
    if [ -d "/Applications/BetterTouchTool.app" ]; then
        info "Importing BetterTouchTool preset..."
        open "$BTT_PRESET" 2>/dev/null || warn "Could not import BTT preset (BTT may not be running)"
        ok "BTT preset imported (mouse buttons, gestures, etc.)"
    else
        warn "BetterTouchTool not installed yet — will import preset on next run"
    fi
else
    warn "config/btt_preset.bttpreset not found — place it next to setup_mac.sh"
    info "To create one: BTT > Presets > right-click > Export Preset"
fi

########################################
# 19. Whisper model + subtitle script
########################################
section "Whisper model + subtitle tools"

WHISPER_MODEL_DIR="$HOME/models"
WHISPER_MODEL="$WHISPER_MODEL_DIR/ggml-large-v3-turbo-q8_0.bin"

if [ -f "$WHISPER_MODEL" ]; then
    ok "Whisper model already downloaded"
else
    info "Downloading whisper large-v3-turbo model (~1GB)..."
    mkdir -p "$WHISPER_MODEL_DIR"
    curl -L -o "$WHISPER_MODEL" \
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q8_0.bin" 2>/dev/null && \
        ok "Whisper model downloaded to $WHISPER_MODEL" || \
        warn "Whisper model download failed — retry manually"
fi

# Install subtitle script to /usr/local/bin
SUBTITLE_SRC="$SCRIPT_DIR/scripts/subtitle.sh"
if [ -f "$SUBTITLE_SRC" ]; then
    sudo cp "$SUBTITLE_SRC" /usr/local/bin/subtitle
    sudo chmod +x /usr/local/bin/subtitle
    ok "subtitle command installed to /usr/local/bin/subtitle"
    info "Usage: subtitle /path/to/movie.mkv"
    info "       subtitle /path/to/media/          # batch"
    info "       subtitle /path/to/media/ --recursive"
else
    warn "scripts/subtitle.sh not found — place it next to setup_mac.sh"
fi

# Add Metal acceleration env var to zsh_user_custom (don't clobber existing content)
if ! grep -q "GGML_METAL_PATH_RESOURCES" "$HOME/.zsh_user_custom" 2>/dev/null; then
    cat >> "$HOME/.zsh_user_custom" << 'WHISPER_EOF'

# Whisper.cpp Metal GPU acceleration (Apple Silicon)
export GGML_METAL_PATH_RESOURCES="$(brew --prefix whisper-cpp 2>/dev/null)/share/whisper-cpp"
WHISPER_EOF
    ok "Whisper Metal env var added to ~/.zsh_user_custom"
fi

########################################
# 20. AI Agents (OpenClaw + Hermes)
########################################
section "AI Agents"

# ── OpenClaw ──────────────────────────────────────────────────────────────
# Personal AI assistant framework. Requires Node 22+ (installed via brew above).
# After install, run: openclaw onboard --install-daemon
if command -v openclaw &>/dev/null; then
    ok "OpenClaw already installed ($(openclaw --version 2>/dev/null || echo 'unknown version'))"
else
    info "Installing OpenClaw..."
    npm install -g openclaw@latest 2>/dev/null && \
        ok "OpenClaw installed" || \
        warn "OpenClaw install failed (may need Node 22+ — run: nvm install 22)"
fi

# ── Hermes Agent (commented out — walk through setup manually post-install) ──
# Self-improving AI agent by Nous Research. Installs its own Python/deps.
# To install manually:
#   curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
#   hermes setup
# if command -v hermes &>/dev/null; then
#     ok "Hermes Agent already installed"
# else
#     info "Installing Hermes Agent..."
#     curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash 2>/dev/null && \
#         ok "Hermes Agent installed" || \
#         warn "Hermes Agent install failed"
# fi

info ""
info "AI agents require interactive setup after install:"
info "  OpenClaw:  openclaw onboard --install-daemon"
info "  Hermes:    (commented out — install manually when ready)"
info "These configure your LLM provider (API keys) and messaging channels."

########################################
# 21. Summary
########################################
section "Setup Complete!"

echo -e "${GREEN}What you got:${NC}"
echo ""
echo "  Applications:"
echo "    Browsers:       Chrome, Firefox (default)"
echo "    Communication:  Discord, Slack, Zulip"
echo "    Development:    Android Studio, VS Code, Docker, iTerm2, Fork, GitUp,"
echo "                    GitHub Desktop, Claude Code"
echo "    AI/LLM:         Claude Desktop, Ollama, OpenClaw"
echo "    Media:          Jellyfin, Grayjay, Spotify, VLC, MX Player"
echo "    Networking:     Tailscale, OpenVPN Connect, Microsoft Remote Desktop"
echo "    Utilities:      BetterTouchTool, Raycast, Karabiner-Elements,"
echo "                    KeepingYouAwake, AppCleaner, The Unarchiver,"
echo "                    GrandPerspective, Stats, Bitwarden, ForkLift,"
echo "                    Cyberduck, Radio Silence"
echo "    Gaming/Creative: Steam, Godot, Aseprite"
echo "    Virtualization: UTM"
echo ""
echo "  Terminal + Dev:"
echo "    Zsh vi-mode, Ctrl-R search, 10M line history"
echo "    Fish-like autosuggestions + syntax highlighting"
echo "    Vim: gruvbox, NERDTree, mouse/trackpad, bell disabled"
echo "    Git: colored diffs, diff-highlight, aliases"
echo "    CLI: whisper-cpp, ffmpeg, Claude Code, bitwarden-cli, neovim, gh, tea"
echo "    Python venv: /opt/brobpy (activated by default)"
echo "    subtitle command: generate .srt files for Jellyfin (whisper-cpp)"
echo "    All bells/beeps disabled (zsh, vim, iTerm, system)"
echo ""
echo "  Browser extensions (auto-installed):"
echo "    Firefox: uBlock Origin, Bitwarden, OneTab"
echo "    Chrome:  uBlock Origin Lite, Bitwarden, OneTab, Claude"
echo ""
echo "  Preferences:"
echo "    All animations disabled, tiling margins removed"
echo "    Fast key repeat, no autocorrect/smart quotes"
echo "    Finder: list view, hidden files, path bar, home in sidebar"
echo "    Finder sidebar: Recents/Tags/iCloud Drive removed"
echo "    Screenshots: ~/Screenshots, PNG, no shadow"
echo "    Desktop background solid black, iTerm2 background black"
echo "    Auto-launch disabled: Spotify, Docker, Slack, Discord, Steam"
echo "    Microsoft Auto-Update killed"
echo "    BetterTouchTool preset imported (config/btt_preset.bttpreset)"
echo "      Globe/fn key → Mission Control (like GNOME Super key)"
echo "      Ctrl+Shift+K → Toggle KeepingYouAwake"
echo "      Mouse Button 4/5 → Back/Forward (Cmd+[/])"
echo "      Mouse scroll inversion for mice (trackpad unchanged)"
echo ""

echo -e "${YELLOW}  Manual steps:${NC}"
echo ""
echo "  1. REBOOT for all preferences to take effect"
echo "  2. Sign in: Tailscale, Bitwarden, Steam, Discord, Slack, Spotify,"
echo "     Zulip, OpenVPN Connect (import .ovpn profiles)"
echo "  3. Permissions (System Settings > Privacy & Security):"
echo "     Accessibility: BetterTouchTool, Karabiner, Raycast"
echo "     Full Disk Access: iTerm, GrandPerspective"
echo "  4. Git identity: git config --global user.name/email"
echo "  5. Chrome extensions: verify at chrome://policy (may need manual install)"
echo "  6. Ollama: ollama pull llama3"
echo "  7. AI Agents:"
echo "     openclaw onboard --install-daemon"
echo "     Hermes (optional): curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash"
echo "  8. BTT: open BetterTouchTool and verify preset triggers imported correctly"
echo "     Globe/fn → Mission Control, Ctrl+Shift+K → KeepingYouAwake, Mouse 4/5 → Back/Fwd"
echo "  9. Android Studio: complete setup wizard on first launch"
echo " 10. AirCaption: download from https://www.aircaption.com/download"
echo " 11. TODO — CornerFix: https://github.com/makalin/CornerFix"
echo " 12. TODO — Window management / Spaces: pick and configure one of:"
echo "     AeroSpace: brew install --cask nikitabobko/tap/aerospace"
echo "     yabai+skhd: brew install koekeishiya/formulae/yabai koekeishiya/formulae/skhd"
echo "     Or stick with BetterTouchTool + macOS native tiling"
echo " 12. Custom shell config: ~/.zsh_user_custom"
echo ""

if [ ${#MANUAL_STEPS[@]} -gt 0 ]; then
    echo -e "${RED}  Items needing attention:${NC}"
    for step in "${MANUAL_STEPS[@]}"; do
        echo "     - $step"
    done
    echo ""
fi

if [ ${#FAILED_CASKS[@]} -gt 0 ]; then
    echo -e "${RED}  Failed casks — retry with:${NC}"
    echo "     brew update && brew cleanup"
    for cask in "${FAILED_CASKS[@]}"; do
        echo "     brew install --cask $cask"
    done
    echo ""
fi

if $BACKUP_DOTFILES && [ -n "${BACKUP_DIR:-}" ]; then
    echo "  Dotfile backups: $BACKUP_DIR"
    echo ""
fi
