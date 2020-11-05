# MacPorts
# this includes (tmux and rxvt-unicode)
export PATH="/opt/local/bin:/opt/local/sbin:/usr/local/sbin:$PATH"

# X11
[[ -d /opt/X11/bin ]] && export PATH="/opt/X11/bin:$PATH"

# MySQL
[[ -d /usr/local/mysql/bin ]] && export PATH="/usr/local/mysql/bin:$PATH"

# Rustup
[[ -f $HOME/.cargo/env ]] && source $HOME/.cargo/env

# Haskell binaries from cabal
[[ -d $HOME/Library/Haskell/bin ]] && export PATH="$HOME/Library/Haskell/bin:$PATH"

# Go's idiocy of requiring a path
[[ -d $HOME/Projects/go ]] && export GOPATH="$HOME/Projects/go"
[[ -d /opt/local/lib/go ]] && export GOROOT="/opt/local/lib/go"

# Postgresql
[[ -d /Applications/Postgres.app/Contents/Versions/latest/bin ]] && export PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH"

# Mactex
[[ -d /usr/local/texlive/2015/bin/x86_64-darwin ]] && export PATH="$PATH:/usr/local/texlive/2015/bin/x86_64-darwin"

# Java Maven
[[ -f /usr/libexec/java_home ]] && export JAVA_HOME=$(/usr/libexec/java_home)
MAVEN_OPTS=-Dfile.encoding=UTF-8

# Clojurescript
export CLOJURESCRIPT_HOME=$HOME/Projects/Clones/clojurescript
export LEIN_ROOT=/opt/local/bin/lein

# Python PIP and other user stuff
[[ -d $HOME/.local/bin ]] && export PATH="$HOME/.local/bin:$PATH"
