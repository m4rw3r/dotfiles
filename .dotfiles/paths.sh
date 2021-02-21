
# Rustup
[[ -f $HOME/.cargo/env ]] && source $HOME/.cargo/env

# Python PIP and other user stuff
[[ -d $HOME/.local/bin ]] && export PATH="$HOME/.local/bin:$PATH"

# OS X

# MacPorts
# this includes (tmux and rxvt-unicode)
[[ -d /opt/local ]] && export PATH="/opt/local/bin:/opt/local/sbin:/usr/local/sbin:$PATH"

# X11
[[ -d /opt/X11/bin ]] && export PATH="/opt/X11/bin:$PATH"

# MySQL
[[ -d /usr/local/mysql/bin ]] && export PATH="/usr/local/mysql/bin:$PATH"

