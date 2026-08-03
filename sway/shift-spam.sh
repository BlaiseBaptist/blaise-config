#!/bin/bash
# Toggle: rapidly taps left Shift (keycode 42) in the background.
# First press starts the loop, second press (same hotkey) stops it.

PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/shift-spam.pid"

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
kill "$(cat "$PIDFILE")"
rm -f "$PIDFILE"
exit 0
fi

(
echo $BASHPID > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT
while :; do
ydotool key 42:1
sleep 0.05
ydotool key 42:0
sleep 0.05
done
) &
disown
