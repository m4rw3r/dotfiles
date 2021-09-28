export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

if command -v nvim &>/dev/null; then
	export GIT_EDITOR="nvim"
else
	export GIT_EDITOR="vim"
fi

source $HOME/.dotfiles/paths.sh
