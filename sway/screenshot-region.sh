#!/bin/bash
# Region screenshot of the screen as it was when the hotkey was pressed.
#
# Usage:
#   screenshot-region.sh <output.png> [--copy]
#
# The whole layout is grabbed with grim before anything else starts, so menus
# and tooltips that close on the next redraw are still in the shot. wayfreeze
# then shows a frozen frame while slurp picks the region, and the region is
# cropped out of the first grab (not re-captured), so slurp's own selection box
# can never end up in the image.

set -u
out=$1
copy=${2:-}
wayfreeze=$(command -v wayfreeze || echo "$HOME/.cargo/bin/wayfreeze")

tmp=$(mktemp --suffix=.png)
freeze=
cleanup() {
	[ -n "$freeze" ] && kill "$freeze" 2>/dev/null
	rm -f "$tmp" "$tmp.frozen"
}
trap cleanup EXIT

grim "$tmp" || exit 1

if [ -x "$wayfreeze" ]; then
	"$wayfreeze" --hide-cursor --after-freeze-cmd "touch $tmp.frozen" &
	freeze=$!
	# slurp must map after the freeze overlay or it ends up underneath it.
	for _ in $(seq 100); do
		[ -e "$tmp.frozen" ] && break
		kill -0 "$freeze" 2>/dev/null || break
		sleep 0.01
	done
fi

geom=$(slurp -d) || exit 0 # Escape cancels

# slurp reports logical layout coordinates; grim's full grab starts at the
# layout's top-left and is rendered at the largest output scale.
read -r ox oy scale < <(swaymsg -t get_outputs | jq -r '
	[.[] | select(.active)]
	| "\(map(.rect.x) | min) \(map(.rect.y) | min) \(map(.scale) | max)"')
read -r left top width height < <(echo "$geom" | awk -v ox="$ox" -v oy="$oy" -v s="$scale" '
	{ split($1, p, ","); split($2, d, "x")
	  printf "%d %d %d %d\n", (p[1]-ox)*s+0.5, (p[2]-oy)*s+0.5, d[1]*s+0.5, d[2]*s+0.5 }')

mkdir -p "$(dirname "$out")"
vips crop "$tmp" "$out" "$left" "$top" "$width" "$height" || exit 1
[ "$copy" = --copy ] && wl-copy --type image/png <"$out"

# Notification previewing the shot; clicking it opens the image.
# --copy reuses one path, so take a copy for the preview: a later shot would
# otherwise change the image of an older notification still in swaync.
preview=$(mktemp --tmpdir screenshot-preview.XXXXXX.png)
cp "$out" "$preview"
(
	# Image only: swaync renders <img> in the body as a large preview.
	action=$(notify-send -a Screenshot -A default=Open \
		"" "<img src=\"$preview\" alt=\"Screenshot\"/>")
	[ "$action" = default ] && xdg-open "$out"
	rm -f "$preview"
) >/dev/null 2>&1 &
disown
exit 0
