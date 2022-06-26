#!/bin/bash

function config {
	/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME $@
}

config checkout

if [ $? = 0 ]; then
	echo "Checked out config.";
else
	echo "Backing up existing dotfiles.";

	mkdir -p .config-backup

	config checkout 2>&1 | egrep "\s+\." | awk {'print $1'} | xargs -I{} mv {} .config-backup/{}
fi;

config checkout
config config status.showUntrackedFiles no
