export GIT_EDITOR="vim"

source $HOME/.paths.sh

# X and rxvt-unicode
export   LANG=en_US.UTF-8
export   LC_ALL=en_US.UTF-8

# X and rxvt-unicode
[[ -f ~/.Xdefaults ]] && xrdb -merge ~/.Xdefaults
[[ -f ~/.Xmodmap ]]   && xmodmap ~/.Xmodmap 

xsetroot -solid black
xsetroot -cursor_name left_ptr
 
[[ -f /opt/local/share/fonts/fonts.dir ]] && xset fp+ /opt/local/share/fonts/
xset fp+ $HOME/Library/Fonts/
xset fp rehash 
