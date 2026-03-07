#!/bin/sh
set -eu

Z13CTL_BIN=${Z13CTL_BIN:-z13ctl}
STATE_FILE=${Z13CTL_STATE_FILE:-${XDG_STATE_HOME:-$HOME/.local/state}/niri/kbd-backlight-level}

read_current() {
    if [ -r "$STATE_FILE" ]; then
        current=$(tr -d '[:space:]' < "$STATE_FILE")
    else
        current=
    fi

    case "$current" in
        0|1|2|3|4)
            printf '%s\n' "$current"
            ;;
        *)
            printf '%s\n' 0
            ;;
    esac
}

current=${KBD_BACKLIGHT_CURRENT:-$(read_current)}

case "$current" in
    0|1)
        next_state=2
        next=low
        ;;
    2)
        next_state=3
        next=medium
        ;;
    3)
        next_state=4
        next=high
        ;;
    4)
        next_state=1
        next=off
        ;;
    *)
        next_state=2
        next=low
        ;;
esac

"$Z13CTL_BIN" brightness "$next"

mkdir -p "$(dirname "$STATE_FILE")"
printf '%s\n' "$next_state" > "$STATE_FILE"
