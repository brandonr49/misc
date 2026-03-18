#!/bin/bash
#
# Mac Terminal Setup Script
# Adapted from the QP IT repo's Fedora terminal configuration
# Installs: iTerm2, zsh plugins, vim + plugins, git config, dotfiles
#
# Usage: bash ~/setup_mac_terminal.sh
#
# Safe to re-run (idempotent).

set -e

YELLOW='\033[1;33m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
NC='\033[0m' # No Color

info()  { echo -e "${CYAN}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }

########################################
# 1. Homebrew
########################################
if ! command -v brew &>/dev/null; then
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    ok "Homebrew already installed"
fi

# Ensure brew is on PATH for this script (Apple Silicon)
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"

########################################
# 2. iTerm2 (recommended terminal)
########################################
if [ ! -d "/Applications/iTerm.app" ]; then
    info "Installing iTerm2..."
    brew install --cask iterm2
else
    ok "iTerm2 already installed"
fi

########################################
# 3. Zsh plugins (autosuggestions + syntax highlighting)
########################################
info "Installing zsh plugins via Homebrew..."
brew install zsh-autosuggestions zsh-syntax-highlighting 2>/dev/null || true
ok "Zsh plugins installed"

########################################
# 4. Vim (latest) + dependencies
########################################
info "Installing modern vim..."
brew install vim 2>/dev/null || true
ok "Vim installed"

########################################
# 5. Git (latest from Homebrew for diff-highlight)
########################################
info "Installing git from Homebrew (includes diff-highlight)..."
brew install git 2>/dev/null || true
ok "Git installed"

########################################
# 6. Useful extras
########################################
info "Installing tree and other handy tools..."
brew install tree 2>/dev/null || true
ok "Extras installed"

########################################
# 7. Backup existing dotfiles
########################################
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
# 8. Zsh alias file (~/.zsh_alias)
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
# 9. Zsh PS1 prompt (~/.zsh_ps1)
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
# 10. Zshrc (~/.zshrc)
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
# 11. Vim setup (~/.vim/.vimrc + Vundle)
########################################
info "Setting up Vim with Vundle and plugins..."
mkdir -p ~/.vim/bundle

# Install Vundle if not present
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

" SuperTab completion
let g:SuperTabDefaultCompletionType = "context"
let g:SuperTabCrMapping=1
VIMRC_EOF

# Symlink so `vim` finds it at the standard path too
ln -sf ~/.vim/.vimrc ~/.vimrc

# Install Vundle plugins non-interactively
info "Installing Vim plugins (this may take a moment)..."
vim +PluginInstall +qall 2>/dev/null
ok "Vim configured with gruvbox + NERDTree + SuperTab + CtrlP"

########################################
# 12. Git config (~/.gitconfig)
########################################
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

# Make diff-highlight executable if found
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
# 13. Git global ignore
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
# Done
########################################
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN} Mac terminal setup complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "What you got:"
echo "  - iTerm2 (open it from /Applications)"
echo "  - Zsh with vi-mode + Ctrl-R search + Ctrl-A/E"
echo "  - 10M line history with timestamps and dedup"
echo "  - Fish-like autosuggestions (gray text as you type)"
echo "  - Syntax highlighting (commands colored as you type)"
echo "  - Colored prompt: [user@host:path] - (git-branch) %"
echo "  - Vim with gruvbox dark theme, NERDTree, CtrlP, SuperTab"
echo "  - Git with colored diffs, diff-highlight, aliases (gs, gl, gd, etc.)"
echo ""
echo "Next steps:"
echo "  1. Open iTerm2 (for best color support)"
echo "  2. In iTerm2: Preferences > Profiles > Colors > set background to dark"
echo "  3. Source your new config:  source ~/.zshrc"
echo "  4. If git user/email not set, run:"
echo "       git config --global user.name 'Your Name'"
echo "       git config --global user.email 'you@example.com'"
echo "  5. Put any personal customizations in ~/.zsh_user_custom"
echo ""
echo "Dotfile backups saved to: $BACKUP_DIR"
