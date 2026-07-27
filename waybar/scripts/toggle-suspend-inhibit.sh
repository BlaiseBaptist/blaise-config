#!/bin/bash
# Paired with waybar's idle_inhibitor "on-click": that module's click already
# toggles its own wayland idle-inhibit lock (blocks screen blanking via
# swayidle), but that lock is invisible to logind, so lid-close suspend
# ignores it. This mirrors the same click into a systemd-logind inhibitor
# lock that actually blocks suspend/lid-switch.
pidfile="$HOME/.cache/waybar-suspend-inhibit.pid"

if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
	kill "$(cat "$pidfile")"
	rm -f "$pidfile"
else
	systemd-inhibit --what=handle-lid-switch:sleep \
		--who="waybar-idle-inhibitor" \
		--why="Manually toggled via waybar idle inhibitor" \
		--mode=block \
		sleep infinity &
	echo $! >"$pidfile"
fi
