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
#   - Safe to re-run (idempotent)
#   - Some steps require being signed into the Mac App Store first
#   - After running, a reboot is recommended for all preferences to take effect
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

# Cache sudo credentials upfront so the script can run unattended.
# A background process refreshes the timestamp so it doesn't expire mid-run.
info "Requesting sudo password (will be cached for the duration of this script)..."
sudo -v
while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null' EXIT
ok "sudo credentials cached"

# Track what we couldn't install for the summary
MANUAL_STEPS=()

########################################
# 1. Xcode Command Line Tools
########################################
section "Xcode Command Line Tools"

if xcode-select -p &>/dev/null; then
    ok "Xcode Command Line Tools already installed"
else
    info "Installing Xcode Command Line Tools..."
    xcode-select --install 2>/dev/null || true
    # Wait for installation to complete
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

info "Updating Homebrew..."
brew update --quiet
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
    mas          # Mac App Store CLI
)

for tool in "${CLI_TOOLS[@]}"; do
    if brew list "$tool" &>/dev/null; then
        ok "$tool already installed"
    else
        info "Installing $tool..."
        brew install "$tool" 2>/dev/null || warn "Failed to install $tool"
    fi
done

# xcodes for Xcode management (separate tap)
if brew list xcodesorg/made/xcodes &>/dev/null; then
    ok "xcodes already installed"
else
    info "Installing xcodes (Xcode version manager)..."
    brew install xcodesorg/made/xcodes 2>/dev/null || warn "Failed to install xcodes"
fi

ok "CLI tools installed"

########################################
# 4. Cask applications
########################################
section "GUI Applications (brew cask)"

CASK_APPS=(
    # Browsers
    google-chrome
    firefox

    # Communication
    discord
    slack

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
        brew install --cask "$app" 2>/dev/null || warn "Failed to install $app (may need manual install)"
    fi
done

ok "GUI applications installed"

########################################
# 5. Xcode (full IDE via xcodes)
########################################
section "Xcode IDE"

if [ -d "/Applications/Xcode.app" ]; then
    ok "Xcode already installed"
else
    if command -v xcodes &>/dev/null; then
        info "Installing latest Xcode via xcodes (this is ~13GB, may take a while)..."
        info "You may be prompted for Apple ID credentials."
        xcodes install --latest --experimental-unxip || {
            warn "Xcode install failed or was skipped"
            MANUAL_STEPS+=("Install Xcode: run 'xcodes install --latest' or install from the App Store")
        }
    else
        warn "xcodes not available, skipping Xcode install"
        MANUAL_STEPS+=("Install Xcode from the Mac App Store or via 'xcodes install --latest'")
    fi
fi

# Accept Xcode license if installed
if [ -d "/Applications/Xcode.app" ]; then
    info "Accepting Xcode license..."
    sudo xcodebuild -license accept 2>/dev/null || true
    sudo xcodebuild -runFirstLaunch 2>/dev/null || true
    ok "Xcode license accepted"
fi

########################################
# 6. Remove default bloat apps
########################################
section "Removing default bloat applications"

BLOAT_APPS=(
    "/Applications/GarageBand.app"
    "/Applications/iMovie.app"
    "/Applications/Keynote.app"
    "/Applications/Pages.app"
    "/Applications/Numbers.app"
)

for app in "${BLOAT_APPS[@]}"; do
    app_name=$(basename "$app" .app)
    if [ -d "$app" ]; then
        info "Removing $app_name..."
        sudo rm -rf "$app" 2>/dev/null && ok "Removed $app_name" || warn "Could not remove $app_name (SIP protected?)"
    else
        ok "$app_name already removed (or never installed)"
    fi
done

########################################
# 7. macOS Preferences
########################################
section "macOS Preferences"

info "Configuring system preferences..."

# ── Animations: kill them all ──────────────────────────────────────────────

# Disable window opening/closing animations
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false

# System-wide reduce motion
defaults write com.apple.universalaccess reduceMotion -bool true

# Disable Dock animations
defaults write com.apple.dock autohide-time-modifier -float 0       # instant autohide
defaults write com.apple.dock autohide-delay -float 0               # no delay before autohide
defaults write com.apple.dock launchanim -bool false                 # no launch bounce
defaults write com.apple.dock expose-animation-duration -float 0.1   # fast Mission Control

# Disable Finder animations
defaults write com.apple.finder DisableAllAnimations -bool true

# Fast Mission Control animation
defaults write com.apple.dock missioncontrol-animation-duration -float 0.1

# Disable smooth scrolling (the rubber-band bounce)
defaults write NSGlobalDomain NSScrollAnimationEnabled -bool false

# Disable Quick Look animation
defaults write -g QLPanelAnimationDuration -float 0

# Disable window resize animation
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

# Disable spring-loading delay for directories
defaults write NSGlobalDomain com.apple.springing.delay -float 0

# Use scale effect for minimize (faster than genie)
defaults write com.apple.dock mineffect -string "scale"

# Disable Info/Get Info animation
defaults write com.apple.finder AnimateInfoPanes -bool false

ok "Animations disabled"

# ── Window tiling ──────────────────────────────────────────────────────────

# Remove margins between tiled windows
defaults write com.apple.WindowManager EnableTiledWindowMargins -bool false

ok "Tiling margins disabled"

# ── Finder ─────────────────────────────────────────────────────────────────

# Show path bar at bottom of Finder
defaults write com.apple.finder ShowPathbar -bool true

# Show status bar at bottom of Finder
defaults write com.apple.finder ShowStatusBar -bool true

# Show full POSIX path in Finder title bar
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# Show all file extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Show hidden files
defaults write com.apple.finder AppleShowAllFiles -bool true

# Default to list view in Finder (options: Nlsv, icnv, clmv, glyv)
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# New Finder window opens home directory
defaults write com.apple.finder NewWindowTarget -string "PfHm"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/"

# Search the current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Disable warning when changing file extensions
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Disable warning when emptying trash
defaults write com.apple.finder WarnOnEmptyTrash -bool false

# Avoid creating .DS_Store on network and USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Enable spring-loaded folders (drag-hover to open)
defaults write NSGlobalDomain com.apple.springing.enabled -bool true

ok "Finder preferences set"

# ── Keyboard ───────────────────────────────────────────────────────────────

# Fast key repeat rate
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Disable auto-correct
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Disable auto-capitalization
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false

# Disable smart quotes
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

# Disable smart dashes
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Disable auto-period with double space
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# Enable full keyboard access (tab through all UI controls)
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

ok "Keyboard preferences set"

# ── Trackpad ───────────────────────────────────────────────────────────────

# Enable tap to click
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Increase tracking speed (0.0 to 3.0)
defaults write NSGlobalDomain com.apple.trackpad.scaling -float 2.0

ok "Trackpad preferences set"

# ── Dock ───────────────────────────────────────────────────────────────────

# Auto-hide the Dock
defaults write com.apple.dock autohide -bool true

# Set Dock icon size
defaults write com.apple.dock tilesize -int 48

# Don't show recent apps in Dock
defaults write com.apple.dock show-recents -bool false

# Minimize windows into their application icon
defaults write com.apple.dock minimize-to-application -bool true

ok "Dock behavior preferences set"

# ── Screenshots ────────────────────────────────────────────────────────────

# Create screenshots directory
mkdir -p "${HOME}/Screenshots"

# Save screenshots to ~/Screenshots
defaults write com.apple.screencapture location -string "${HOME}/Screenshots"

# Save as PNG
defaults write com.apple.screencapture type -string "png"

# Disable shadow on window screenshots
defaults write com.apple.screencapture disable-shadow -bool true

ok "Screenshot preferences set"

# ── Dialogs ────────────────────────────────────────────────────────────────

# Expand save dialogs by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Expand print dialogs by default
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

ok "Dialog preferences set"

# ── Clock / Menu Bar ──────────────────────────────────────────────────────

# 24-hour clock in menu bar
defaults write com.apple.menuextra.clock Show24Hour -bool true

# Show battery percentage
defaults write com.apple.menuextra.battery ShowPercent -string "YES"

ok "Menu bar preferences set"

# ── Security ──────────────────────────────────────────────────────────────

# Require password immediately after sleep or screensaver
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

ok "Security preferences set"

# ── Misc ──────────────────────────────────────────────────────────────────

# Disable the "Are you sure you want to open this app?" dialog
defaults write com.apple.LaunchServices LSQuarantine -bool false

# Save to disk (not iCloud) by default
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# Disable press-and-hold for keys in favor of key repeat
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Disable automatic termination of inactive apps
defaults write NSGlobalDomain NSDisableAutomaticTermination -bool true

# Disable Resume system-wide (re-open windows on login)
defaults write com.apple.systempreferences NSQuitAlwaysKeepsWindows -bool false

# Enable text selection in Quick Look
defaults write com.apple.finder QLEnableTextSelection -bool true

ok "Misc preferences set"

# ── Apply changes ─────────────────────────────────────────────────────────

info "Restarting affected services..."
for service in Finder Dock SystemUIServer; do
    killall "$service" 2>/dev/null || true
done
ok "Preferences applied (some may require logout/reboot)"

########################################
# 8. Dock layout
########################################
section "Dock layout"

if command -v dockutil &>/dev/null; then
    info "Clearing Dock..."
    dockutil --remove all --no-restart 2>/dev/null || true

    DOCK_APPS=(
        "/Applications/Firefox.app"
        "/Applications/Google Chrome.app"
        "/Applications/Discord.app"
        "/Applications/iTerm.app"
        "/Applications/Claude.app"
        "/Applications/OpenVPN Connect.app"
        "/Applications/Microsoft Remote Desktop.app"
    )

    for app in "${DOCK_APPS[@]}"; do
        app_name=$(basename "$app" .app)
        if [ -d "$app" ]; then
            dockutil --add "$app" --no-restart 2>/dev/null && ok "Pinned $app_name" || warn "Could not pin $app_name"
        else
            warn "$app_name not found in /Applications — skipping dock pin"
        fi
    done

    killall Dock 2>/dev/null || true
    ok "Dock layout configured"
else
    warn "dockutil not installed — skipping Dock layout"
    MANUAL_STEPS+=("Configure Dock manually: dockutil was not available")
fi

########################################
# 9. Backup existing dotfiles
########################################
section "Dotfiles"

BACKUP_DIR=~/dotfiles_backup_$(date +%Y%m%d_%H%M%S)
NEEDS_BACKUP=false

for f in ~/.zshrc ~/.zsh_alias ~/.zsh_ps1 ~/.vim/.vimrc ~/.gitconfig; do
    if [ -f "$f" ]; then
        NEEDS_BACKUP=true
        break
    fi
done

if $NEEDS_BACKUP; then
    info "Backing up existing dotfiles to $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    for f in ~/.zshrc ~/.zsh_alias ~/.zsh_ps1 ~/.vim/.vimrc ~/.gitconfig; do
        if [ -f "$f" ]; then
            cp "$f" "$BACKUP_DIR/" 2>/dev/null || true
        fi
    done
    ok "Backup complete"
fi

########################################
# 10. Zsh alias file (~/.zsh_alias)
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
# ls (macOS compatible - uses -G for color instead of --color=auto)
alias l="ls -lhtrG"
alias ls="ls -lhtrG"
alias la="ls -laG"

####################################################################################################
# misc general use
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
# Military Time Formatting
alias date='date "+%a %b %d %H:%M:%S %Z %Y"'

####################################################################################################
# macOS specific
alias showfiles="defaults write com.apple.finder AppleShowAllFiles YES; killall Finder"
alias hidefiles="defaults write com.apple.finder AppleShowAllFiles NO; killall Finder"
alias flushdns="sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder"
ALIAS_EOF
ok "~/.zsh_alias written"

########################################
# 11. Zsh PS1 prompt (~/.zsh_ps1)
########################################
info "Writing ~/.zsh_ps1"
cat > ~/.zsh_ps1 << 'PS1_EOF'
# Colorized prompt matching the QP IT repo style
# Format: [user@host:path] - (git-branch) %
COLOR1="%F{#1E90FF}" # dodger blue - username
COLOR2="%F{#00FF00}" # green - hostname
COLOR4="%F{#FFA500}" # orange - git branch
WHITE="%F{#FFFFFF}"

function git_branch_name()
{
  branch=$(git symbolic-ref HEAD 2> /dev/null | awk 'BEGIN{FS="/"} {print $NF}')
  if [[ $branch == "" ]];
  then
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
# 12. Zshrc (~/.zshrc)
########################################
info "Writing ~/.zshrc"
cat > ~/.zshrc << 'ZSHRC_EOF'
#
# .zshrc - adapted from QP IT repo for macOS
#

autoload -U compinit
compinit

# Glob: pass failed globs as arguments (needed for scp patterns)
setopt nonomatch

# Allow tab completion in the middle of a word
setopt COMPLETE_IN_WORD

####################################################################################################
# History - large, deduplicated, timestamped
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
# Key bindings - vi mode with familiar bash shortcuts layered on
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

# Fix for macOS Option+Arrow word movement in iTerm2
bindkey "^[f" forward-word
bindkey "^[b" backward-word

####################################################################################################
# Environment
####################################################################################################
export EDITOR=vim
export TIMEFMT=$'\n================\nCPU\t%P\nuser\t%*U\nsystem\t%*S\ntotal\t%*E'

# Terminal title shows working directory
precmd () {print -Pn "\e]0;%~\a"};

# Prompt
source ~/.zsh_ps1

# Aliases
source ~/.zsh_alias

####################################################################################################
# Homebrew PATH (Apple Silicon)
####################################################################################################
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"

####################################################################################################
# User customization (won't be clobbered by re-running setup)
####################################################################################################
if [ -f ~/.zsh_user_custom ]; then
  source ~/.zsh_user_custom
fi

####################################################################################################
# Zsh plugins (installed via Homebrew)
####################################################################################################
BREW_PREFIX="$(brew --prefix 2>/dev/null)"
if [ -n "$BREW_PREFIX" ]; then
    # Autosuggestions (fish-like gray suggestions as you type)
    [ -f "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ] && \
        source "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"

    # Syntax highlighting (colorizes commands as you type - must be last)
    [ -f "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] && \
        source "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

# Fix comment color for dark backgrounds
ZSH_HIGHLIGHT_STYLES[comment]=fg=245
ZSHRC_EOF
ok "~/.zshrc written"

########################################
# 13. Zsh plugins
########################################
info "Installing zsh plugins via Homebrew..."
brew install zsh-autosuggestions zsh-syntax-highlighting 2>/dev/null || true
ok "Zsh plugins installed"

########################################
# 14. Vim setup (~/.vim/.vimrc + Vundle)
########################################
section "Vim"

info "Setting up Vim with Vundle and plugins..."
mkdir -p ~/.vim/bundle

if [ ! -d ~/.vim/bundle/Vundle.vim ]; then
    git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
fi

cat > ~/.vim/.vimrc << 'VIMRC_EOF'
if v:lang =~ "utf8$" || v:lang =~ "UTF-8$"
   set fileencodings=ucs-bom,utf-8,latin1
endif

" Vundle plugin manager
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

" Jump to last cursor position when reopening a file
if has("autocmd")
  augroup jumpback
  autocmd!
  autocmd BufReadPost *
  \ if line("'\"") > 0 && line ("'\"") <= line("$") |
  \   exe "normal! g'\"" |
  \ endif
  augroup END
endif

" Syntax and search highlighting
if &t_Co > 2 || has("gui_running")
  syntax on
  set hlsearch
endif

filetype plugin indent on
syntax enable

let mapleader=","

" Appearance - gruvbox dark theme
set t_Co=256
set background=dark
silent! colorscheme gruvbox
set nu
set hlsearch

" Indentation - 4 spaces
set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab

set backspace=indent,eol,start

" Mouse / trackpad support - scroll and click inside vim
set mouse=a
if has('mouse_sgr')
  set ttymouse=sgr
elseif !has('nvim')
  set ttymouse=xterm2
endif

" SuperTab completion
let g:SuperTabDefaultCompletionType = "context"
let g:SuperTabCrMapping=1
VIMRC_EOF

ln -sf ~/.vim/.vimrc ~/.vimrc

info "Installing Vim plugins (this may take a moment)..."
vim +PluginInstall +qall 2>/dev/null
ok "Vim configured with gruvbox + NERDTree + SuperTab + CtrlP"

########################################
# 15. Git config (~/.gitconfig)
########################################
section "Git"

info "Writing ~/.gitconfig"

# Find diff-highlight for Homebrew git
DIFF_HIGHLIGHT=""
for candidate in \
    "$(brew --prefix git 2>/dev/null)/share/git-core/contrib/diff-highlight/diff-highlight" \
    "/opt/homebrew/share/git-core/contrib/diff-highlight/diff-highlight" \
    "/usr/local/share/git-core/contrib/diff-highlight/diff-highlight"; do
    if [ -f "$candidate" ]; then
        DIFF_HIGHLIGHT="$candidate"
        break
    fi
done

if [ -n "$DIFF_HIGHLIGHT" ]; then
    chmod +x "$DIFF_HIGHLIGHT" 2>/dev/null || true
fi

# Preserve existing user name/email if set
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

########################################
# 16. Git global ignore
########################################
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
# 17. Post-install hooks
########################################
section "Post-install"

# Start Ollama service and pull a default model
if command -v ollama &>/dev/null; then
    info "Ollama installed — you can pull models with: ollama pull llama3"
else
    ok "Ollama not on PATH yet (will be after app launch)"
fi

########################################
# 18. Summary
########################################
section "Setup Complete!"

echo -e "${GREEN}What you got:${NC}"
echo ""
echo "  Applications:"
echo "    Browsers:       Chrome, Firefox"
echo "    Communication:  Discord, Slack"
echo "    Development:    Android Studio, VS Code, Docker, iTerm2, Fork, GitUp, Xcode (if installed)"
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
echo "    Zsh with vi-mode + Ctrl-R search + Ctrl-A/E"
echo "    10M line history with timestamps and dedup"
echo "    Fish-like autosuggestions + syntax highlighting"
echo "    Colored prompt: [user@host:path] - (git-branch) %"
echo "    Vim with gruvbox dark theme, NERDTree, CtrlP, SuperTab"
echo "    Git with colored diffs, diff-highlight, aliases"
echo ""
echo "  Preferences:"
echo "    All animations disabled"
echo "    Window tiling margins removed"
echo "    Fast key repeat, no autocorrect/smart quotes"
echo "    Finder: list view, extensions, hidden files, path bar"
echo "    Screenshots saved to ~/Screenshots as PNG (no shadow)"
echo "    Expanded save/print dialogs"
echo "    24-hour clock, battery percentage"
echo "    Dock: auto-hide, no recents, scale minimize"
echo ""
echo "  Dock pinned apps:"
echo "    Firefox | Chrome | Discord | iTerm | Claude | OpenVPN | RDP"
echo ""

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  Manual steps required:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  1. REBOOT for all preferences to take effect"
echo ""
echo "  2. Sign into accounts:"
echo "     - Tailscale: launch the app and authenticate"
echo "     - Bitwarden: sign in to your vault"
echo "     - Steam, Discord, Slack, Spotify: sign into each"
echo "     - OpenVPN Connect: import your .ovpn profiles"
echo ""
echo "  3. Grant permissions (System Settings > Privacy & Security):"
echo "     - Accessibility: BetterTouchTool, Karabiner-Elements, Raycast"
echo "     - Full Disk Access: iTerm, GrandPerspective, Terminal"
echo "     - Screen Recording: any screen sharing tools"
echo ""
echo "  4. Git identity (if not already set):"
echo "     git config --global user.name 'Your Name'"
echo "     git config --global user.email 'you@example.com'"
echo ""
echo "  5. Browser extensions (must be installed manually):"
echo "     Open Chrome/Firefox and install your extensions from their stores"
echo ""
echo "  6. iTerm2 setup:"
echo "     Preferences > Profiles > Colors > set background to dark"
echo "     (or import a saved profile if you have one)"
echo ""
echo "  7. Ollama models:"
echo "     ollama pull llama3       # or whichever models you want"
echo ""
echo "  8. Android Studio first-run:"
echo "     Launch Android Studio and complete the setup wizard"
echo "     (SDK, emulator images, license acceptance)"
echo ""
echo "  9. TODO — CornerFix (square window corners):"
echo "     https://github.com/makalin/CornerFix"
echo "     Clone, build with Xcode, and run to overlay square corners."
echo "     This is a visual overlay, not a system mod — no SIP changes needed."
echo ""
echo " 10. Personal customizations:"
echo "     Put anything extra in ~/.zsh_user_custom (sourced by .zshrc)"
echo ""

# Print any accumulated failures
if [ ${#MANUAL_STEPS[@]} -gt 0 ]; then
    echo -e "${RED}  Items that need attention:${NC}"
    for step in "${MANUAL_STEPS[@]}"; do
        echo "     - $step"
    done
    echo ""
fi

echo "  Dotfile backups saved to: $BACKUP_DIR"
echo ""
