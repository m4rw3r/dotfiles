if ! (( $+commands[tmux] )); then
  print "tmux.sh: tmux not found." >&2

  return 1
fi

# Side-channel communication to see if we actually attempted to reattach
_tmux_found_free=""

# Attempts to find the first non-attached tmux session and attach to it
function _attach_to_free() {
  local sess=$(tmux list-sessions 2>/dev/null | grep -v "(attached)" | cut -d ":" -f 1 | head)

  if [[ -z "$sess" ]]; then
    _tmux_found_free="false"
  else
    _tmux_found_free="true"
    tmux attach -t $sess
  fi
}

function _tmux_start_session() {
  _attach_to_free

  # We could not reattach
  if [[ $_tmux_found_free = "false" ]]; then
    tmux new-session
  fi

  # Existing a successful session from attach or new-session should not close
  # the window but try to restore another session. Use the WM or terminal to
  # close the window itself before killing all sessions.
  while [[ $? = 0 ]]; do
    _attach_to_free
    [[ $? = 0 && $_tmux_found_free = "true" ]] || break
  done

  # If the last exit was ok, exit the terminal too
  if [[ $_tmux_found_free = "false" && $? = 0 ]]; then
    exit 0
  fi

  # Keep user in shell if anything went wrong so the user can fix it
}

if [[ -z "$TMUX" && -z "$INSIDE_EMACS" && -z "$EMACS" && -z "$VIM" ]]; then
  _tmux_start_session
fi
