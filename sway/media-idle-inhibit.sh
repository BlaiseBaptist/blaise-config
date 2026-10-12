#!/bin/bash
# swayidle only holds off its dpms-off timeout for wayland idle-inhibit locks.
# Plenty of players never take one: jellyfin-desktop, for instance, asks for
# org.freedesktop.ScreenSaver.Inhibit over D-Bus, which nothing under sway
# answers, so the screen blanked mid-episode. This polls MPRIS for players
# that are Playing, finds each one's window by the PID owning its bus name,
# and sets `inhibit_idle visible` on it — so the screen stays on only while
# the playing window is actually on screen. The inhibit is cleared once the
# player pauses, stops or exits.
#
# A background audio player whose window is visible also keeps the screen on;
# MPRIS can't tell video from audio.

declare -A inhibited # pid -> 1, for windows this script put an inhibit on

player_pid() {
	busctl --user status "org.mpris.MediaPlayer2.$1" 2>/dev/null |
		sed -n 's/^PID=//p'
}

while true; do
	declare -A playing=()
	while read -r player; do
		[ "$(playerctl -p "$player" status 2>/dev/null)" = Playing ] || continue
		pid=$(player_pid "$player")
		[ -n "$pid" ] && playing[$pid]=1
	done < <(playerctl -l 2>/dev/null)

	for pid in "${!playing[@]}"; do
		[ -n "${inhibited[$pid]}" ] && continue
		swaymsg -q "[pid=$pid] inhibit_idle visible" 2>/dev/null && inhibited[$pid]=1
	done
	for pid in "${!inhibited[@]}"; do
		[ -n "${playing[$pid]}" ] && continue
		# Fails harmlessly if the window is already gone.
		swaymsg -q "[pid=$pid] inhibit_idle none" 2>/dev/null
		unset "inhibited[$pid]"
	done
	unset playing

	sleep 5
done
