#!/bin/sh

# OS X
if [[ -d /usr/local/sbin ]]; then
	export PATH="/usr/local/sbin:$PATH"
fi
## MacPorts
if [[ -d /opt/local/bin ]]; then
	export PATH="/opt/local/bin:$PATH"
fi
if [[ -d /opt/local/sbin ]]; then
	export PATH="/opt/local/sbin:$PATH"
fi
## X11
if [[ -d /opt/X11/bin ]]; then
	export PATH="/opt/X11/bin:$PATH"
fi
## MySQL
if [[ -d /usr/local/mysql/bin ]]; then
	export PATH="/usr/local/mysql/bin:$PATH"
fi

# Rustup
if [[ -f $HOME/.cargo/env ]]; then
	source $HOME/.cargo/env
fi
# Python PIP and other user stuff
if [[ -d $HOME/.local/bin ]]; then
	export PATH="$HOME/.local/bin:$PATH"
fi
