#!/bin/bash
# Toggle a screen recording with wf-recorder. Run once to start, again to stop.
#
# Usage:
#   screenrecord.sh [region|output] [--audio]
#
# region (default) lets you drag a box with slurp; output records the output
# under the cursor. --audio adds the default sink's monitor (what you hear).
# Files go to ~/Videos/<timestamp>_rec.mp4. Encoding uses VAAPI on the Intel
# GPU so the CPU stays free; if that fails it falls back to libx264.

set -u
pidfile=${XDG_RUNTIME_DIR:-/tmp}/screenrecord.pid

notify() { notify-send -a screenrecord -t 3000 "$@" 2>/dev/null || true; }

if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
	# SIGINT makes wf-recorder finish the file cleanly.
	kill -INT "$(cat "$pidfile")"
	exit 0
fi

mode=${1:-region}
audio=${2:-}

case $mode in
region)
	geom=$(slurp -d) || exit 0 # Escape cancels
	target=(-g "$geom")
	;;
output)
	out=$(swaymsg -t get_outputs | jq -r '.[] | select(.focused) | .name')
	target=(-o "$out")
	;;
*)
	echo "usage: $(basename "$0") [region|output] [--audio]" >&2
	exit 1
	;;
esac

args=()
if [ "$audio" = --audio ]; then
	args+=(--audio="$(pactl get-default-sink).monitor")
fi

mkdir -p ~/Videos
file=~/Videos/$(date +%Y%m%d_%Hh%Mm%Ss)_rec.mp4

(
	wf-recorder "${target[@]}" "${args[@]}" -f "$file" \
		-c h264_vaapi -d /dev/dri/renderD128 &
	echo $! >"$pidfile"
	wait $!
	rc=$?
	# VAAPI can fail on odd region sizes; retry in software if nothing was written.
	if [ ! -s "$file" ]; then
		wf-recorder "${target[@]}" "${args[@]}" -f "$file" -c libx264 -p preset=veryfast &
		echo $! >"$pidfile"
		wait $!
	fi
	rm -f "$pidfile"
	if [ -s "$file" ]; then
		notify "Recording saved" "$file"
	else
		notify -u critical "Recording failed" "wf-recorder exited with $rc"
	fi
) &

notify "Recording started" "Press the same key again to stop"
