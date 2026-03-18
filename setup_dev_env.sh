#!/bin/bash
#
# Fedora Developer Environment Setup
# Installs zsh plugins, vim with plugins, and shell dotfiles.
# This is the terminal/vim portion only — no git config, no system services.
#
# Usage: sudo bash setup_dev_env.sh
#
# Safe to re-run (idempotent).

set -e

YELLOW='\033[1;33m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root (sudo)." >&2
    exit 1
fi

########################################
# 1. Install packages
########################################
info "Installing zsh, vim, and plugins..."
dnf install -y \
    zsh \
    vim-enhanced \
    zsh-autosuggestions \
    zsh-syntax-highlighting \
    git \
    tree \
    2>/dev/null
ok "Packages installed"

########################################
# 2. Set zsh as default shell (for all new users via skel)
########################################
# This only affects the skel copies below — individual users
# can be switched with: chsh -s /bin/zsh <username>

########################################
# 3. Write /etc/skel/.zsh_alias
########################################
info "Writing /etc/skel/.zsh_alias"
cat > /etc/skel/.zsh_alias << 'ALIAS_EOF'
####################################################################################################
# cd up a directory
alias ..="cd ../"
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."

####################################################################################################
# ls
alias l="ls -lhtr --color=auto"
alias ls="ls -lhtr --color=auto"
alias la="ls -la --color=auto"
alias lt="ls -T"
alias lta="lt -a"
alias lat="lta"

####################################################################################################
# misc general use
alias df='df -h'
alias bashrc='vim ~/.bashrc'
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
ALIAS_EOF
ok "/etc/skel/.zsh_alias written"

########################################
# 4. Write /etc/skel/.zsh_ps1
########################################
info "Writing /etc/skel/.zsh_ps1"
cat > /etc/skel/.zsh_ps1 << 'PS1_EOF'
# Colorized prompt
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
ok "/etc/skel/.zsh_ps1 written"

########################################
# 5. Write /etc/skel/.zshrc
########################################
info "Writing /etc/skel/.zshrc"
cat > /etc/skel/.zshrc << 'ZSHRC_EOF'
#
# .zshrc — QP standard developer environment
#

autoload -U compinit
compinit

# Glob: pass failed globs as arguments (needed for scp patterns)
setopt nonomatch

# Allow tab completion in the middle of a word
setopt COMPLETE_IN_WORD

####################################################################################################
# History — large, deduplicated, timestamped
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
# Key bindings — vi mode with familiar bash shortcuts layered on
####################################################################################################
bindkey -v
bindkey '^R' history-incremental-search-backward
bindkey '^A' beginning-of-line
bindkey '^E' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[2~' quoted-insert
bindkey '^[[H'  beginning-of-line
bindkey '^[[F'  end-of-line
bindkey '^[[5'  beginning-of-history
bindkey '^[[6'  end-of-history
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word

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
# LD_LIBRARY_PATH mod needed by exanic
####################################################################################################
LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib
export LD_LIBRARY_PATH

####################################################################################################
# User customization (won't be clobbered by re-running setup)
####################################################################################################
if [ -f ~/.zsh_user_custom ]; then
  source ~/.zsh_user_custom
fi

####################################################################################################
# Zsh plugins
####################################################################################################
ZSH_PLUGINS=/usr/share/
source $ZSH_PLUGINS/zsh-autosuggestions/zsh-autosuggestions.zsh

# Syntax highlighting — must be last sourced plugin
source $ZSH_PLUGINS/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
ZSH_HIGHLIGHT_STYLES[comment]=fg=245
ZSHRC_EOF
ok "/etc/skel/.zshrc written"

########################################
# 6. Vim setup in /etc/skel
########################################
info "Setting up Vim in /etc/skel..."
mkdir -p /etc/skel/.vim/bundle

# Install Vundle into skel if not present
if [ ! -d /etc/skel/.vim/bundle/Vundle.vim ]; then
    git clone https://github.com/VundleVim/Vundle.vim.git /etc/skel/.vim/bundle/Vundle.vim
fi

cat > /etc/skel/.vim/.vimrc << 'VIMRC_EOF'
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

" Appearance — gruvbox dark theme
set t_Co=256
set background=dark
silent! colorscheme gruvbox
set nu
set hlsearch

" Indentation — 4 spaces
set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab

set backspace=indent,eol,start

" SuperTab completion
let g:SuperTabDefaultCompletionType = "context"
let g:SuperTabCrMapping=1

" Recognize .d files as c++
autocmd BufNewFile,BufReadPost *.d set filetype=cpp
VIMRC_EOF

ok "Vim configured in /etc/skel"

########################################
# Done
########################################
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN} Developer environment setup complete${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Installed to /etc/skel/ (applies to new users automatically)."
echo ""
echo "To apply to an existing user, copy the files:"
echo "  cp /etc/skel/.zshrc /etc/skel/.zsh_alias /etc/skel/.zsh_ps1 ~<user>/"
echo "  cp -r /etc/skel/.vim ~<user>/"
echo "  chown -R <user>:<user> ~<user>/.zshrc ~<user>/.zsh_* ~<user>/.vim"
echo "  chsh -s /bin/zsh <user>"
echo ""
echo "What's included:"
echo "  - Zsh with vi-mode + Ctrl-R search + Ctrl-A/E"
echo "  - 10M line history with timestamps and dedup"
echo "  - Fish-like autosuggestions (gray text as you type)"
echo "  - Syntax highlighting (commands colored as you type)"
echo "  - Colored prompt: [user@host:path] - (git-branch) %"
echo "  - Vim with gruvbox dark theme, NERDTree, CtrlP, SuperTab"
echo "  - Git aliases (gs, gd, gl, gco, etc.)"
