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
# Pnpm
if [[ -d "$PNPM_HOME" ]]; then
	export PATH="$PNPM_HOME:$PATH"
fi
# Snap
if [[ -d "/snap/bin" ]]; then
	export PATH="$PATH:/snap/bin"
fi
# Neovim via bob (https://github.com/MordechaiHadad/bob)
if [[ -d "$HOME/.local/share/bob/nvim-bin" ]]; then
	export PATH="$HOME/.local/share/bob/nvim-bin:$PATH"
fi
# OpenCode
if [[ -d "$HOME/.opencode/bin" ]]; then
	export PATH="$HOME/.opencode/bin:$PATH"
fi
