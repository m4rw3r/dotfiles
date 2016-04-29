export   LANG=en_US.UTF-8
export   LC_ALL=en_US.UTF-8

# MacPorts
export PATH=/opt/local/bin:/opt/local/sbin:$PATH

# Path to your oh-my-zsh configuration.
ZSH=$HOME/dotfiles/oh-my-zsh
ZSH_CUSTOM=$HOME/dotfiles/oh-my-zsh-plugins

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="robbyrussell"

# Uncomment this to disable bi-weekly auto-update checks
# DISABLE_AUTO_UPDATE="true"

# Uncomment to change how often before auto-updates occur? (in days)
# export UPDATE_ZSH_DAYS=13

# Uncomment following line if you want to disable colors in ls
# DISABLE_LS_COLORS="true"

# Uncomment following line if you want to disable autosetting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment following line if you want to disable command autocorrection
# DISABLE_CORRECTION="true"

# Uncomment following line if you want red dots to be displayed while waiting for completion
# COMPLETION_WAITING_DOTS="true"

# Uncomment following line if you want to disable marking untracked files under
# VCS as dirty. This makes repository status check for large repositories much,
# much faster.
DISABLE_UNTRACKED_FILES_DIRTY="true"

ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)

# Tmux
ZSH_TMUX_AUTOSTART="true"
ZSH_TMUX_FIXTERM="false"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
plugins=(git github nyan osx macports node npm vi-mode colored-man tmux zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

# Customize to your needs...
unsetopt share_history
setopt   hist_ignore_dups
setopt   hist_ignore_space
export   EDITOR=vim

alias bower='noglob bower'
alias genuuid="uuidgen | tr '[:upper:]' '[:lower:]' | tr -d \"\\n\""

# GitDoge
alias such=git
alias very=git
alias wow='git status'

# Kerberos problems caused by wrong version used by SSH due to MacPorts overriding it
alias kinit='/usr/bin/kinit'
alias klist='/usr/bin/klist'

# Go's idiocy of requiring a path
export GOPATH=~/Projects/go
export GOROOT="/opt/local/lib/go"

# Java Maven
export JAVA_HOME=$(/usr/libexec/java_home)
MAVEN_OPTS=-Dfile.encoding=UTF-8

# Rust
export DYLD_LIBRARY_PATH=/usr/local/lib

# Clojurescript
export CLOJURESCRIPT_HOME=$HOME/Projects/Clones/clojurescript
export LEIN_ROOT=/opt/local/bin/lein

# Postgresql
PATH="/Applications/Postgres.app/Contents/Versions/9.4/bin:$PATH"
# Use this command in psql to enable less pager: \pset pager always
export PAGER=less
export LESS="-r"
# PgTap
alias pg_prove=/opt/local/libexec/perl5.16/sitebin/pg_prove

# Haskell
export PATH="$HOME/Library/Haskell/bin:$PATH"

# Python
export PYTHONPATH=$PYTHONPATH:/opt/local/Library/Frameworks/Python.framework/Versions/2.7/lib/python2.7/site-packages

# Rust cargo install
export PATH="$PATH:$HOME/.multirust/toolchains/nightly/cargo/bin"

# Mactex
export PATH="$PATH:/usr/local/texlive/2015/bin/x86_64-darwin"

# From http://justinlilly.com/dotfiles/zsh.html
extract () {
	if [ -f $1 ] ; then
		case $1 in
			*.tar.bz2)        tar xjf $1        ;;
			*.tar.gz)         tar xzf $1        ;;
			*.bz2)            bunzip2 $1        ;;
			*.rar)            unrar x $1        ;;
			*.gz)             gunzip $1         ;;
			*.tar)            tar xf $1         ;;
			*.tbz2)           tar xjf $1        ;;
			*.tgz)            tar xzf $1        ;;
			*.zip)            unzip $1          ;;
			*.Z)              uncompress $1     ;;
			*)                echo "'$1' cannot be extracted via extract()" ;;
		esac
	else
		echo "'$1' is not a valid file"
	fi
}

if [[ -f $HOME/dotfiles/keys.sh ]]; then
	source $HOME/dotfiles/keys.sh
fi

# added by travis gem
[ -f /Users/m4rw3r/.travis/travis.sh ] && source /Users/m4rw3r/.travis/travis.sh
