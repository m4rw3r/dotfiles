#!/usr/bin/env zsh

# We have to set paths here AGAIN due to MacOS and ZSH file load-order, MacOS
# will update PATH in /etc/zprofile.
#
#  * /etc/zshenv
#  * ~/.zshenv
#  * /etc/zprofile
#  * ${ZDOTDIR:-$HOME}/.zprofile
#  * /etc/zshrc
#  * ${ZDOTDIR:-$HOME}/.zshrc
#  * /etc/zlogin
#  * ${ZDOTDIR:-$HOME}/.zlogin

source "$HOME/.config/paths.sh"

# Ensure path arrays do not contain duplicates.
typeset -gU cdpath fpath mailpath path
