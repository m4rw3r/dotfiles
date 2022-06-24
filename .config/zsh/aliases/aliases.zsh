#!/usr/bin/env zsh

# Navigation
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ~="cd ~"
alias d="dirs -v"

# Dotfiles management alias: https://github.com/m4rw3r/dotfiles/
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'

alias genuuid="uuidgen | tr '[:upper:]' '[:lower:]' | tr -d \"\\n\""
# GitDoge
alias such=git
alias very=git
alias wow='git status'

alias mysql='mysql --auto-vertical-output --show-warnings --sigint-ignore --line-numbers --compress'
alias mysqlp='mysql --auto-vertical-output --show-warnings --sigint-ignore --pager=less --line-numbers --column-type-info --compress'
# TODO: Inform all NeoVIM instances to also swap on this
alias light='kitty +kitten themes --cache-age=365 Base16-tomorrow' # not sure why this is uppercase
alias dark='kitty +kitten themes --cache-age=365 Base16-tomorrow-night'
# KCachegrind for visualizing profiles
alias kcachegrind='docker run --rm -e DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix -v "$HOME:$HOME" -w "$PWD" -e "HOME=$HOME" quetzacoalt/kcachegrind kcachegrind'

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
