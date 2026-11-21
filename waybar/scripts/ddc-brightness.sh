#!/bin/sh
# Brightness for external monitors over DDC/CI (littlearch has no backlight).
#
#   ddc-brightness.sh            print waybar JSON for the current level
#   ddc-brightness.sh up|down    step all monitors by $step percent
#   ddc-brightness.sh set N      set all monitors to N percent
#
# A ddcutil write takes ~100-350 ms per monitor, far slower than a burst of
# wheel ticks. So a step only updates a state file and signals waybar (the bar
# changes instantly); a single background applier then pushes the latest value
# to every monitor, looping until the value stops changing, so a burst of
# scroll events collapses into one or two DDC writes.
#
# ddcutil's udev rule tags the i2c buses uaccess, so no group is needed.
set -eu

step=5
signal=9 # keep in sync with "signal" in config.jsonc

dir=${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is not set}/ddc-brightness
mkdir -p "$dir"
value_file=$dir/value
buses_file=$dir/buses

detect_buses() {
	# Only "Display N" blocks; laptop panels show up as "Invalid display".
	ddcutil detect --terse 2>/dev/null |
		awk '/^Display / { ok = 1 } /^Invalid display/ { ok = 0 }
			ok && sub(/^ *I2C bus: *\/dev\/i2c-/, "") { print }' >"$buses_file"
}

buses() {
	[ -s "$buses_file" ] || detect_buses
	cat "$buses_file"
}

clamp() {
	v=$1
	case "$v" in -*) v=0 ;; *[!0-9]*|'') v=100 ;; esac
	[ "$v" -le 100 ] || v=100
	printf '%s' "$v"
}

current() {
	if [ ! -s "$value_file" ]; then
		bus=$(buses | head -n1)
		v=
		[ -n "$bus" ] &&
			v=$(ddcutil --bus "$bus" getvcp 10 --terse 2>/dev/null | awk '{ print $4 }')
		clamp "${v:-100}" >"$value_file"
	fi
	cat "$value_file"
}

apply() {
	# One applier at a time; later steps just update $value_file.
	exec 8>"$dir/apply.lock"
	flock -n 8 || return 0
	last=
	retries=2
	while v=$(cat "$value_file") && [ "$v" != "$last" ]; do
		pids=
		for b in $(buses); do
			ddcutil --bus "$b" --noverify setvcp 10 "$v" >/dev/null 2>&1 &
			pids="$pids $!"
		done
		failed=
		for p in $pids; do wait "$p" || failed=1; done
		# A monitor was unplugged or swapped: re-detect and retry. Give up
		# after a couple of tries (a monitor in standby may not answer DDC).
		if [ -n "$failed" ] && [ "$retries" -gt 0 ]; then
			retries=$((retries - 1))
			detect_buses
			continue
		fi
		last=$v
	done
}

# change +N | -N | N
change() {
	exec 9>"$dir/value.lock"
	flock -x 9
	case "$1" in
	[+-]*) new=$(($(current) $1)) ;;
	*) new=$1 ;;
	esac
	clamp "$new" >"$value_file"
	flock -u 9
	pkill -RTMIN+"$signal" -x waybar || true
	apply
}

case "${1:-show}" in
up) change "+$step" ;;
down) change "-$step" ;;
set) change "${2:?usage: $0 set PERCENT}" ;;
show)
	v=$(current)
	n=$(buses | wc -l)
	printf '{"text":"%s%%","percentage":%s,"tooltip":"Monitor brightness: %s%% (%s display%s, DDC/CI)\\nScroll to change, click for 85%%"}\n' \
		"$v" "$v" "$v" "$n" "$([ "$n" -eq 1 ] || echo s)"
	;;
*) echo "usage: $0 [show|up|down|set PERCENT]" >&2; exit 2 ;;
esac
