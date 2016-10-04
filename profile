export GIT_EDITOR="vim"
# Haskell binaries from cabal
export PATH="$HOME/Library/Haskell/bin:$PATH"
# X and rxvt-unicode
export PATH=/opt/local/bin:/opt/local/sbin:/opt/X11/bin:$PATH
# Go installation
export GOROOT="/opt/local/lib/go"
# Rust
export DYLD_LIBRARY_PATH=/usr/local/lib

# Rustup
[[ -f $HOME/.cargo/env ]] && source $HOME/.cargo/env

# X and rxvt-unicode
export   LANG=en_US.UTF-8
export   LC_ALL=en_US.UTF-8

# X and rxvt-unicode
[[ -f ~/.Xdefaults ]] && xrdb -merge ~/.Xdefaults
[[ -f ~/.Xmodmap ]]   && xmodmap ~/.Xmodmap 

xsetroot -solid black
xsetroot -cursor_name left_ptr
 
xset fp+ /opt/local/share/fonts/
xset fp+ $HOME/Library/Fonts/
xset fp rehash 
