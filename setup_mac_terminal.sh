#!/bin/bash
#
# Mac Full Setup Script
# Installs applications, configures macOS preferences, sets up terminal environment.
#
# Usage:
#   bash ~/setup_mac.sh
#
# IMPORTANT: Do NOT run with sudo. Run as your normal user.
#   The script will prompt for sudo only when specific commands need it.
#
#   Safe to re-run (idempotent).
#   After running, a reboot is recommended for all preferences to take effect.
#

set -e

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
# 1. Xcode Command Line Tools
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

########################################
# 4. Dotfiles — backup
########################################
section "Dotfiles"

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
    ok "Backup complete"
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
COLOR1="%F{#1E90FF}"
COLOR2="%F{#00FF00}"
COLOR4="%F{#FFA500}"
WHITE="%F{#FFFFFF}"

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
# 10. macOS Preferences
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

# ── Misc ──────────────────────────────────────────────────────────────────
defaults write com.apple.LaunchServices LSQuarantine -bool false
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain NSDisableAutomaticTermination -bool true
defaults write com.apple.systempreferences NSQuitAlwaysKeepsWindows -bool false
defaults write com.apple.finder QLEnableTextSelection -bool true
ok "Misc set"

# ── iTerm2 bell ───────────────────────────────────────────────────────────
defaults write com.googlecode.iterm2 "Silence bell" -bool true 2>/dev/null || true
ok "iTerm2 bell silenced"

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

    # Gaming
    steam

    # Virtualization
    utm
)

for app in "${CASK_APPS[@]}"; do
    if brew list --cask "$app" &>/dev/null; then
        ok "$app already installed"
    else
        info "Installing $app..."
        if brew install --cask "$app" 2>&1; then
            ok "$app installed"
        else
            warn "Failed to install $app"
            FAILED_CASKS+=("$app")
        fi
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
        "/Applications/iTerm.app" \
        "/Applications/Claude.app" \
        "/Applications/OpenVPN Connect.app" \
        "/Applications/Microsoft Remote Desktop.app"; do
        [ -d "$app" ] && dockutil --add "$app" --no-restart 2>/dev/null || true
    done

    killall Dock 2>/dev/null || true
    ok "Dock layout set"
else
    warn "dockutil not found — configure Dock manually"
fi

########################################
# 14. Xcode IDE
########################################
section "Xcode IDE"


if [ -d "/Applications/Xcode.app" ]; then
    ok "Xcode already installed"
else
    if command -v mas &>/dev/null; then
        if mas account &>/dev/null 2>&1; then
            info "Installing Xcode via Mac App Store (~13GB, may take a while)..."
            mas install 497799835 || {
                warn "Xcode install via mas failed"
                MANUAL_STEPS+=("Install Xcode: open App Store or run 'mas install 497799835'")
            }
        else
            warn "Not signed into Mac App Store — cannot install Xcode automatically"
            MANUAL_STEPS+=("Sign into App Store, then: mas install 497799835")
        fi
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
# 15. Summary
########################################
section "Setup Complete!"

echo -e "${GREEN}What you got:${NC}"
echo ""
echo "  Applications:"
echo "    Browsers:       Chrome, Firefox"
echo "    Communication:  Discord, Slack, Zulip"
echo "    Development:    Android Studio, VS Code, Docker, iTerm2, Fork, GitUp"
echo "    AI/LLM:         Claude Desktop, Ollama"
echo "    Media:          Jellyfin, Grayjay, Spotify, VLC"
echo "    Networking:     Tailscale, OpenVPN Connect, Microsoft Remote Desktop"
echo "    Utilities:      BetterTouchTool, Raycast, Karabiner-Elements,"
echo "                    KeepingYouAwake, AppCleaner, The Unarchiver,"
echo "                    GrandPerspective, Stats, Bitwarden"
echo "    Gaming:         Steam"
echo "    Virtualization: UTM"
echo ""
echo "  Terminal:"
echo "    Zsh vi-mode, Ctrl-R search, 10M line history"
echo "    Fish-like autosuggestions + syntax highlighting"
echo "    Vim: gruvbox, NERDTree, mouse/trackpad, bell disabled"
echo "    Git: colored diffs, diff-highlight, aliases"
echo "    All bells/beeps disabled (zsh, vim, iTerm, system)"
echo ""
echo "  Preferences:"
echo "    All animations disabled, tiling margins removed"
echo "    Fast key repeat, no autocorrect/smart quotes"
echo "    Finder: list view, extensions, hidden files, path bar"
echo "    Screenshots: ~/Screenshots, PNG, no shadow"
echo "    Dock: auto-hide, no recents, scale minimize"
echo "    System sounds disabled"
echo ""
echo "  Dock: Firefox | Chrome | Discord | iTerm | Claude | OpenVPN | RDP"
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
echo "  5. Browser extensions: install manually from stores"
echo "  6. iTerm2: Profiles > Colors > dark background"
echo "  7. Ollama: ollama pull llama3"
echo "  8. Android Studio: complete setup wizard on first launch"
echo "  9. TODO — CornerFix: https://github.com/makalin/CornerFix"
echo " 10. Custom shell config: ~/.zsh_user_custom"
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

echo "  Dotfile backups: $BACKUP_DIR"
echo ""
