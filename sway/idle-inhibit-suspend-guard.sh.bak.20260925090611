#!/bin/bash
# Sway's swayidle already skips its own timeouts (dpms off, lock) when a
# window holds a wayland idle-inhibit lock, since sway withholds idle
# notifications from swayidle in that case. But systemd-logind's lid-switch
# suspend (HandleLidSwitch=suspend in logind.conf) is a separate path that
# knows nothing about wayland idle-inhibit locks, so closing the lid still
# suspends even while e.g. a video player is inhibiting idle. This polls
# sway's tree for an active idle inhibitor and holds a logind inhibitor lock
# (blocking both lid-switch and idle-timer suspend) for as long as one exists.

inhibit_pid=""

has_inhibitor() {
	swaymsg -t get_tree |
		jq -e '.. | .idle_inhibitors? // empty | select(.application == "enabled" or .user == "enabled")' \
		>/dev/null 2>&1
}

while true; do
	if has_inhibitor; then
		if [ -z "$inhibit_pid" ] || ! kill -0 "$inhibit_pid" 2>/dev/null; then
			systemd-inhibit --what=handle-lid-switch:sleep \
				--who="sway-idle-inhibit-guard" \
				--why="a window is holding a wayland idle-inhibit lock" \
				--mode=block \
				sleep infinity &
			inhibit_pid=$!
		fi
	else
		if [ -n "$inhibit_pid" ] && kill -0 "$inhibit_pid" 2>/dev/null; then
			kill "$inhibit_pid" 2>/dev/null
			wait "$inhibit_pid" 2>/dev/null
			inhibit_pid=""
		fi
	fi
	sleep 5
done
