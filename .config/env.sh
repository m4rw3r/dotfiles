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

# Rustup
[[ -f $HOME/.cargo/env ]] && source $HOME/.cargo/env
# Python PIP and other user stuff
[[ -d $HOME/.local/bin ]] && export PATH="$HOME/.local/bin:$PATH"

# OS X

# MacPorts, this includes (tmux and rxvt-unicode)
[[ -d /opt/local ]] && export PATH="/opt/local/bin:/opt/local/sbin:/usr/local/sbin:$PATH"
# X11
[[ -d /opt/X11/bin ]] && export PATH="/opt/X11/bin:$PATH"
# MySQL
[[ -d /usr/local/mysql/bin ]] && export PATH="/usr/local/mysql/bin:$PATH"
