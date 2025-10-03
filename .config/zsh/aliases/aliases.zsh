#!/usr/bin/env zsh

# Navigation
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ~="cd ~"
alias d="dirs -v"

# Alias sudo to sudo with a trailing space, this means the next word should *also* be checked for alias expansion
alias sudo='sudo '

# Dotfiles management alias: https://github.com/m4rw3r/dotfiles/
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'

alias genuuid="uuidgen | tr '[:upper:]' '[:lower:]' | tr -d \"\\n\""
# GitDoge
alias such=git
alias very=git
alias wow='git status'

alias mysql='mysql --auto-vertical-output --show-warnings --sigint-ignore --line-numbers'
alias mysqlp='mysql --auto-vertical-output --show-warnings --sigint-ignore --pager=less --line-numbers --column-type-info'
alias json_escape='jq -aR'
# TODO: Inform all NeoVIM instances to also swap on this
alias light='echo "include themes/base16-tomorrow.conf" > $XDG_CONFIG_HOME/kitty/current-theme.conf && kitty +runpy "from kitty.utils import *; reload_conf_in_all_kitties()"'
alias dark='echo "include themes/base16-tomorrow-night.conf" > $XDG_CONFIG_HOME/kitty/current-theme.conf && kitty +runpy "from kitty.utils import *; reload_conf_in_all_kitties()"'
# KCachegrind for visualizing profiles
alias kcachegrind='docker run --rm -e DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix -v "$HOME:$HOME" -w "$PWD" -e "HOME=$HOME" quetzacoalt/kcachegrind kcachegrind'
# Dive, analyzes Docker Images
alias dive="docker run -ti --rm  -v /var/run/docker.sock:/var/run/docker.sock docker.io/wagoodman/dive"
# Wget does not have any configuration variable for default file location
alias wget=wget --hsts-file="$XDG_CACHE_HOME/wget-hsts"
# Clear with clearing scrollback as well in multiple terminals (Kitty, iTerm2, Apple Terminal)
alias clear="printf '\\033[2J\\033[3J\\033[1;1H'"

# Use NeoVIM
if command -v nvim &>/dev/null; then
	alias vim=nvim
fi

# Kitty kittens
if test -n "$KITTY_INSTALLATION_DIR"; then
	alias icat="kitty +kitten icat"
	# Kitty terminfo does not work well on older linux-servers for some reason, fallback to xterm-256color
	alias s="TERM=xterm-256color kitty +kitten ssh"
	alias kdiff="kitty +kitten diff"
fi

# Colorize stuff
if ls --color >/dev/null 2>&1; then # GNU `ls`
	colorflag="--color=auto"
else # OS X `ls`
	colorflag="-G"
fi
if [[ "$INSIDE_EMACS" ]]; then
	colorflag=""
fi

# Always use color output for `ls`
alias ls="command ls -Fh ${colorflag}"
alias grep="command grep --color=auto"

if command -v prettyping &>/dev/null; then
	alias ping='prettyping --nolegend'
fi

# Gzip-enabled `curl`
alias curl="curl -L --compressed"
# Enhanced WHOIS lookups
alias whois="whois -h whois-servers.net"
alias ip="ip --color=auto"

# System management aliases
if  [[ -z $SSH_CLIENT ]] ; then
	alias poweroff="systemctl poweroff"
	alias reboot="systemctl reboot"
	alias hibernate="systemctl suspend"
else
	alias poweroff="sudo systemctl poweroff"
	alias reboot="sudo systemctl reboot"
	alias hibernate="sudo systemctl suspend"
fi

alias q="exit"
