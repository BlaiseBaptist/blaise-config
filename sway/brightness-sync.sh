#!/bin/sh
# Mirror the built-in panel's backlight onto external monitors over DDC/CI.
#
# Brightness is changed from several places (the XF86MonBrightness keys,
# waybar's backlight scroll and click), all of which only drive
# intel_backlight through brightnessctl. Rather than wrap each of them, poll
# the sysfs value and push its percentage to VCP 0x10 on every DDC-capable
# display. A ddcutil write takes ~100 ms per monitor, so a burst of scroll steps
# collapses into one write of the latest value on the next pass.
#
# ddcutil's udev rule tags the i2c buses uaccess, so no group is needed. The
# display list is re-detected whenever a DRM connector's status changes (dock
# plugged or pulled), and the current level is applied to whatever is new.
#
# At 0% the external outputs are powered off through sway (DDC brightness 0
# only dims them; the panel itself goes dark at raw 0) and powered back on as
# soon as the level rises. Only the transition acts, so wake-outputs.sh and
# swayidle's resume are never fought over an output's power state.
log() { logger -t brightness-sync "$*"; }

command -v ddcutil >/dev/null || { log "ddcutil not installed"; exit 1; }

bl=/sys/class/backlight/intel_backlight
max=$(cat "$bl/max_brightness")

# Only "Display N" blocks; the panel shows up as an "Invalid display".
detect() {
	ddcutil detect --terse 2>/dev/null |
		awk '/^Display / { ok = 1 } /^Invalid display/ { ok = 0 }
			ok && sub(/^ *I2C bus: *\/dev\/i2c-/, "") { print }'
}

externals() {
	swaymsg -t get_outputs 2>/dev/null |
		jq -r '.[] | select(.active and .name != "eDP-1") | .name'
}

set_power() {
	for o in $(externals); do
		swaymsg -q "output $o power $1"
	done
	log "external outputs power $1"
}

connectors() { cat /sys/class/drm/card*-*/status 2>/dev/null | tr '\n' ' '; }

buses=$(detect)
log "displays on i2c buses: ${buses:-none}"
conn=$(connectors)
last=

while :; do
	now=$(connectors)
	if [ "$now" != "$conn" ]; then
		conn=$now
		# Give the monitor time to come out of standby and answer DDC.
		sleep 3
		buses=$(detect)
		log "connectors changed, displays on i2c buses: ${buses:-none}"
		last=
	fi
	pct=$(( ($(cat "$bl/brightness") * 100 + max / 2) / max ))
	if [ "$pct" = 0 ] && [ "$last" != 0 ]; then
		set_power off
	elif [ "$pct" != 0 ] && [ "$last" = 0 ]; then
		set_power on
	fi
	if [ -n "$buses" ] && [ "$pct" != "$last" ]; then
		for b in $buses; do
			ddcutil --bus "$b" --noverify setvcp 10 "$pct" >/dev/null 2>&1 ||
				log "setvcp 10 $pct failed on i2c-$b" &
		done
		wait
	fi
	last=$pct
	sleep 0.3
done
