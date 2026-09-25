#!/bin/sh
# Turn the outputs back on after a resume, and keep at it until sway agrees.
#
# swayidle's after-resume fires on logind's PrepareForSleep(false), the same
# instant seatd hands the session back to sway. On every resume sway drops and
# recreates eDP-1 (wayvnc logs "eDP-1 went away"), and the new eDP-1 inherits
# the `power off` the lid:on bindswitch stored. A single `output * power on`
# that lands before sway has DRM back, or before eDP-1 is recreated, is lost,
# and if the lid-open event never reaches sway nothing else turns the panel on.
# That is how $mod+F9, pull the dock, close the lid left a black screen on wake
# (2026-09-21 20:47, 2026-09-22 12:58): the dock teardown shifts the timing.
#
# So: re-apply every second until every output is on for three checks in a row
# (or 15 s pass). The panel stays off if the lid is really closed (clamshell on
# a dock, woken from the external keyboard).
lid_closed() { grep -q closed /proc/acpi/button/lid/*/state 2>/dev/null; }

good=0
for _ in $(seq 15); do
	if lid_closed; then skip=eDP-1; else skip=; fi
	off=$(swaymsg -t get_outputs 2>/dev/null |
		jq -r --arg skip "$skip" '.[] | select(.power | not) | select(.name != $skip) | .name')
	if [ -z "$off" ] && swaymsg -t get_outputs >/dev/null 2>&1; then
		good=$((good + 1))
		[ "$good" -ge 3 ] && exit 0
	else
		good=0
		for o in $off; do swaymsg -q "output $o power on"; done
	fi
	sleep 1
done
