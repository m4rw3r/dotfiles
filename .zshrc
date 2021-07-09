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
ZSH_THEME="robbyrussell"

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

# Tmux
source ~/.dotfiles/tmux.sh

# Customize to your needs...
unsetopt share_history
setopt   hist_ignore_dups
setopt   hist_ignore_space
export   EDITOR=vim

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

alias mysql='mysql --auto-vertical-output --show-warnings --pager=less --sigint-ignore --line-numbers --column-type-info --compress'

if [ -x "$(command -v prettyping)" ]; then
	alias ping='prettyping --nolegend'
fi

# Use NeoVIM instead of VIM
if [ -x "$(command -v nvim)" ]; then
	alias vim=nvim
fi

if [[ -f $HOME/.dotfiles/keys.sh ]]; then
	source $HOME/.dotfiles/keys.sh
fi

# Create an open command if one does not exist (linux)
if [ -z "$(command -v open)" ]; then
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
