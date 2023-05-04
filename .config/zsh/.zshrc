#/usr/bin/env zsh
emulate zsh

# Lots of this is copied from yramagicman:
# https://gitlab.com/yramagicman/stow-dotfiles/-/blob/master/config/zsh/zshrc

source "$HOME/.config/env.sh"

fpath=("$ZDOTDIR/pkg" $fpath)
fpath=("$ZDOTDIR/functions" $fpath)
fpath=("$ZDOTDIR/prompts" $fpath)
autoload $ZDOTDIR/pkg/*
#autoload $ZDOTDIR/functions/*
#autoload $ZDOTDIR/prompts/*

# Smart URLs, we have to init this before F-Sy-H since otherwise zle will
# override the highlighting, F-Sy-H will automatically call this if defined:
autoload -Uz url-quote-magic
zle -N self-insert url-quote-magic

pkg init
[[ -z "$INSIDE_EMACS" ]] && pkg colored-man-pages -f omz
pkg safe-paste -f omz
pkg jeffreytse/zsh-vi-mode
pkg zsh-users/zsh-completions
pkg z-shell/F-Sy-H
pkg load
pkg update
source "$ZDOTDIR/aliases/aliases.zsh"
if type "dircolors" > /dev/null; then
	eval $(dircolors)
elif type "gdircolors" > /dev/null; then
	eval $(gdircolors)
fi

# Set zsh options for general runtime.
#
# Load the prompt system and completion system and initilize them
autoload -Uz compinit promptinit

# Ensure cache-dir exists
[ ! -d "$XDG_CACHE_HOME/zsh" ] && mkdir -p "$XDG_CACHE_HOME/zsh"

# Load and initialize the completion system ignoring insecure directories with a
# cache time of 20 hours, so it should almost always regenerate the first time a
# shell is opened each day.
_comp_files=($XDG_CACHE_HOME/zsh/zcompcache(Nm-20))
if (( $#_comp_files )); then
	compinit -i -C -d "$XDG_CACHE_HOME/zsh/zcompcache"
else
	compinit -i -d "$XDG_CACHE_HOME/zsh/zcompcache"
fi
unset _comp_files
promptinit
setopt prompt_subst

# Manually load Kitty terminal integration if available
if test -n "$KITTY_INSTALLATION_DIR"; then
	export KITTY_SHELL_INTEGRATION="enabled"
	autoload -Uz -- "$KITTY_INSTALLATION_DIR"/shell-integration/zsh/kitty-integration
	kitty-integration
	unfunction kitty-integration
fi

# load colors
autoload -U colors && colors

# Use case-insensitve globbing.
unsetopt case_glob
# glob dotfiles as well
setopt globdots
# use extended globbing
setopt extendedglob

# Automatically change directory if a directory is entered
setopt autocd

#
# General
#

# Allow brace character class list expansion.
setopt brace_ccl
# Combine zero-length punctuation characters (accents) with the base character.
setopt combining_chars
# Allow 'Henry''s Garage' instead of 'Henry'\''s Garage'.
setopt rc_quotes
# Don't print a warning message if a mail file has been accessed.
unsetopt mail_warning

#
# Jobs
#
# List jobs in the long format by default.
setopt long_list_jobs
# Attempt to resume existing job before creating a new process.
setopt auto_resume
# Report status of background jobs immediately.
setopt notify
# Don't run all background jobs at a lower priority.
unsetopt bg_nice
# Don't kill jobs on shell exit.
unsetopt hup
# Don't report on jobs when shell exit.
unsetopt check_jobs

# turn on corrections
setopt correct
# Disable some shell keyboard shortcuts
stty -ixon > /dev/null 2>/dev/null

# completion
# options
# Complete from both ends of a word.
setopt complete_in_word
# Move cursor to the end of a completed word.
setopt always_to_end
# Perform path search even on command names with slashes.
setopt path_dirs
# Show completion menu on a successive tab press.
setopt auto_menu
# Automatically list choices on ambiguous completion.
setopt auto_list
# If completed parameter is a directory, add a trailing slash.
setopt auto_param_slash
setopt complete_aliases
# Do not autoselect the first completion entry.
unsetopt menu_complete
# Disable start/stop characters in shell editor.
unsetopt flow_control

# zstyle
zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*:matches' group 'yes'
zstyle ':completion:*:options' description 'yes'
zstyle ':completion:*:options' auto-description '%d'
zstyle ':completion:*:corrections' format ' %F{green}-- %d (errors: %e) --%f'
zstyle ':completion:*:descriptions' format ' %F{yellow}-- %d --%f'
zstyle ':completion:*:messages' format ' %F{purple} -- %d --%f'
zstyle ':completion:*:warnings' format ' %F{red}-- no matches found --%f'
zstyle ':completion:*:default' list-prompt '%S%M matches%s'
zstyle ':completion:*' format ' %F{yellow}-- %d --%f'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' verbose yes
zstyle ':completion::complete:*' cache-path "$XDG_CACHE_HOME/zsh/zcompcache"
zstyle ':completion::complete:*' use-cache on
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;34=0=01'
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*:functions' ignored-patterns '(_*|pre(cmd|exec))'
zstyle ':completion:*' completer _complete _ignored _files
zstyle ':completion:*' rehash true
# We want autocompletion to work on 'docker run -it <tab>'
# note that the space is required in this case
zstyle ':completion:*:*:docker:*' option-stacking yes
zstyle ':completion:*:*:docker-*:*' option-stacking yes

zmodload zsh/complist

# history
HISTFILE="$XDG_CACHE_HOME/zsh/history"
HISTSIZE=10000000
SAVEHIST=10000000
setopt appendhistory notify
unsetopt beep nomatch
# Treat the '!' character specially during expansion.
setopt bang_hist
# Write to the history file immediately, not when the shell exits.
setopt inc_append_history
# Do not share history between all sessions.
unsetopt share_history
# Expire a duplicate event first when trimming history.
setopt hist_expire_dups_first
# Do not record an event that was just recorded again.
setopt hist_ignore_dups
# Delete an old recorded event if a new event is a duplicate.
setopt hist_ignore_all_dups
# Do not display a previously found event.
setopt hist_find_no_dups
# Do not record an event starting with a space.
setopt hist_ignore_space
# Do not write a duplicate event to the history file.
setopt hist_save_no_dups
# Do not execute immediately upon history expansion.
setopt hist_verify
# Show timestamp in history
setopt extended_history

ZLE_REMOVE_SUFFIX_CHARS=""
ZVM_INSERT_MODE_CURSOR=$ZVM_CURSOR_BLINKING_UNDERLINE

if [ -f "/usr/share/fzf/key-bindings.zsh" ]; then
	source "/usr/share/fzf/key-bindings.zsh"
fi
if [ -f "/usr/share/fzf/completion.zsh" ]; then
	source /usr/share/fzf/completion.zsh
fi

# Use NeoVIM instead of VIM
if command -v nvim &>/dev/null; then
	export EDITOR=nvim
	export GIT_EDITOR="nvim"
	export VISUAL='nvim'
fi

# Create an open command if one does not exist (linux)
if ! command -v open &>/dev/null; then
	function open() {
		if [ "$#" -ne 1 ]; then
			nohup xdg-open . >/dev/null 2>&1 &
		else
			nohup xdg-open "$@" >/dev/null 2>&1 &
		fi
	}
fi

eval "$(starship init zsh)"
