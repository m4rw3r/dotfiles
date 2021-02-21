#!/bin/bash

function command_exists {
	type "$1" &> /dev/null
}

is_osx() {
	local platform=$(uname)
	[ "$platform" == "Darwin" ]
}

main() {
	if [ $XDG_SESSION_TYPE = "wayland" ] && command_exists "wl-paste"; then
		tmux unbind p
		tmux bind p run "wl-paste -n | tmux load-buffer - && tmux paste-buffer"
	elif is_osx && command_exists "reattach-to-user-namespace"; then
		tmux unbind p
		tmux bind p run "reattach-to-user-namespace pbpaste | tmux load-buffer - && tmux paste-buffer"
	elif is_osx; then
		tmux unbind p
		tmux bind p run "pbpaste | tmux load-buffer - && tmux paste-buffer"
	fi
}

main
