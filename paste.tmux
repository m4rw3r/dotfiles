#!/bin/bash

is_osx() {
	local platform=$(uname)
	[ "$platform" == "Darwin" ]
}

main() {
	if is_osx && command_exists "reattach-to-user-namespace"; then
		tmux unbind p
		tmux bind p run "reattach-to-user-namespace pbpaste | tmux load-buffer - && tmux paste-buffer"
	elif is_osx; then
		tmux unbind p
		tmux bind p run "pbpaste | tmux load-buffer - && tmux paste-buffer"
	fi
}

main
