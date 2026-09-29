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
#
# 2026-09-25 19:24 ($mod+F9, pull the dock, suspend key) woke with eDP-1 not
# just powered off but disabled (active false, no workspace), the only output
# left. Two holes let that through: `power on` alone doesn't re-enable a
# disabled output, so each attempt is `enable power on`; and the firmware
# misreported the lid on that resume, so a lid-closed skip of the only output
# left nothing to check and three empty checks counted as success. The panel is
# now only skipped when another output is up, and success needs one lit output.
lid_closed() { grep -q closed /proc/acpi/button/lid/*/state 2>/dev/null; }
log() { logger -t wake-outputs "$*"; }

good=0
for i in $(seq 15); do
	outputs=$(swaymsg -t get_outputs 2>/dev/null)
	if [ -z "$outputs" ]; then
		good=0
		sleep 1
		continue
	fi
	skip=
	if lid_closed && printf '%s' "$outputs" |
		jq -e '.[] | select(.name != "eDP-1" and .active and .power)' >/dev/null; then
		skip=eDP-1
	fi
	off=$(printf '%s' "$outputs" |
		jq -r --arg skip "$skip" '.[] | select((.active and .power) | not) | select(.name != $skip) | .name')
	lit=$(printf '%s' "$outputs" | jq '[.[] | select(.active and .power)] | length')
	if [ -z "$off" ] && [ "$lit" -gt 0 ]; then
		good=$((good + 1))
		[ "$good" -ge 3 ] && { log "outputs on after ${i}s"; exit 0; }
	else
		good=0
		for o in $off; do
			log "try $i: output $o enable power on"
			swaymsg -q "output $o enable power on"
		done
	fi
	sleep 1
done
log "gave up after 15s: $(swaymsg -t get_outputs 2>/dev/null |
	jq -c '[.[] | {name, active, power}]')"
