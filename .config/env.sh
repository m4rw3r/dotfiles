#!/bin/sh

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-"$HOME/.config"}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-"$HOME/.cache"}"
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
export MODULES_DIR="$ZDOTDIR/plugins"

export VISUAL='vim'
# Use this command in psql to enable less pager: \pset pager always
export PAGER=less
export LESS="-r"

# Use NeoVIM instead of VIM
if command -v nvim &>/dev/null; then
	export EDITOR=nvim
	export GIT_EDITOR="nvim"
	alias vim=nvim
else
	export GIT_EDITOR="vim"
	export EDITOR=vim
fi
