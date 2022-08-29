#!/usr/bin/env zsh

source "$HOME/.config/env.sh"

# Load paths here for scripts, MacOS will overwrite this for interactive login
# shells in /etc/zprofile, so we have to load this file again in .zprofile.
source "$HOME/.config/paths.sh"

# Ensure path arrays do not contain duplicates.
typeset -gU cdpath fpath mailpath path

