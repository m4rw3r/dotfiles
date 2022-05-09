zcompile_or_recompile() {
	local file

	for file in "$@"; do
		if [[ -f "$file" ]] && [[ ! -f "$file.zwc" ]] || [[ "$file" -nt "$file.zwc" ]]; then
			zcompile "$file"
		fi
	done
}

zcompile_or_recompile "$HOME/.zshrc"

export   LANG=en_US.UTF-8
export   LC_ALL=en_US.UTF-8

source $HOME/.dotfiles/paths.sh

# Path to your oh-my-zsh configuration.
ZSH=$HOME/.dotfiles/oh-my-zsh
ZSH_CUSTOM=$HOME/.dotfiles/oh-my-zsh-plugins

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.

# Use an empty name since we override the prompt with Typewritten
ZSH_THEME=""

# Uncomment this to disable bi-weekly auto-update checks
DISABLE_AUTO_UPDATE="true"

# Uncomment to change how often before auto-updates occur? (in days)
# export UPDATE_ZSH_DAYS=13

# Uncomment following line if you want to disable colors in ls
# DISABLE_LS_COLORS="true"

# Uncomment following line if you want to disable autosetting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment following line if you want to disable command autocorrection
# DISABLE_CORRECTION="true"

# Uncomment following line if you want red dots to be displayed while waiting for completion
# COMPLETION_WAITING_DOTS="true"

# Uncomment following line if you want to disable marking untracked files under
# VCS as dirty. This makes repository status check for large repositories much,
# much faster.
DISABLE_UNTRACKED_FILES_DIRTY="true"

ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
plugins=(docker gitfast safe-paste vi-mode zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

# Typewritten prompt (https://github.com/reobin/typewritten)
TYPEWRITTEN_RELATIVE_PATH="adaptive"

fpath+=$HOME/.dotfiles/zsh-typewritten
autoload -U promptinit; promptinit
prompt typewritten

# Tmux
source ~/.dotfiles/tmux.sh

# Customize to your needs...
unsetopt share_history
setopt hist_ignore_dups
setopt hist_ignore_space
export EDITOR=vim

alias genuuid="uuidgen | tr '[:upper:]' '[:lower:]' | tr -d \"\\n\""

# GitDoge
alias such=git
alias very=git
alias wow='git status'

# Use this command in psql to enable less pager: \pset pager always
export PAGER=less
export LESS="-r"

# Dotfiles management alias: https://github.com/m4rw3r/dotfiles/
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'

alias mysql='mysql --auto-vertical-output --show-warnings --sigint-ignore --line-numbers --compress'
alias mysqlp='mysql --auto-vertical-output --show-warnings --sigint-ignore --pager=less --line-numbers --column-type-info --compress'
# TODO: Inform all NeoVIM instances to also swap on this
alias light='kitty +kitten themes --cache-age=365 Base16-tomorrow' # not sure why this is uppercase
alias dark='kitty +kitten themes --cache-age=365 Base16-tomorrow-night'
# KCachegrind for visualizing profiles
alias kcachegrind='docker run --rm -e DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix -v "$HOME:$HOME" -w "$PWD" -e "HOME=$HOME" quetzacoalt/kcachegrind kcachegrind'

if command -v prettyping &>/dev/null; then
	alias ping='prettyping --nolegend'
fi

# Use NeoVIM instead of VIM
if command -v nvim &>/dev/null; then
	export EDITOR=nvim
	alias vim=nvim
fi

if [[ -f $HOME/.dotfiles/keys.sh ]]; then
	source $HOME/.dotfiles/keys.sh
fi

# Create an open command if one does not exist (linux)
if ! command -v open &>/dev/null; then
	function open() {
		if [ "$#" -ne 1 ]; then
			nohup xdg-open . >/dev/null 2>&1
		else
			nohup xdg-open "$@" >/dev/null 2>&1
		fi
	}
fi

# We want autocompletion to work on 'docker run -it <tab>'
# note that the space is required in this case
zstyle ':completion:*:*:docker:*' option-stacking yes
zstyle ':completion:*:*:docker-*:*' option-stacking yes

if [ -f "/usr/share/fzf/key-bindings.zsh" ]; then
	source "/usr/share/fzf/key-bindings.zsh"
fi
