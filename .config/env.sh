#!/bin/sh

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# XDG
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-"$HOME/.cache"}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-"$HOME/.config"}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-"$HOME/.local/share"}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-"/var/run/users/$UID"}"

# Zsh
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
export MODULES_DIR="$ZDOTDIR/plugins"

# NPM XDG support
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME/npm/config"
export NPM_CONFIG_CACHE="$XDG_CACHE_HOME/npm"
#export NPM_CONFIG_TMP="$XDG_RUNTIME_DIR/npm"

# TODO: Drop when we are not using it anymore
# Tmux Plugin Manager
export TMUX_PLUGIN_MANAGER_PATH="$XDG_CONFIG_HOME/tmux/plugins"

export VISUAL='vim'
# Use this command in psql to enable less pager: \pset pager always
export PAGER=less
export LESS="-r"

# Use NeoVIM instead of VIM
if command -v nvim &>/dev/null; then
	export EDITOR=nvim
	export GIT_EDITOR="nvim"
else
	export GIT_EDITOR="vim"
	export EDITOR=vim
fi
