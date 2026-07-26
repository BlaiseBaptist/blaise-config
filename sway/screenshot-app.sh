#!/usr/bin/env bash
# Screenshot a single app window or a whole workspace on Sway, by name.
#
# Usage:
#   screenshot-app.sh app <app_id-or-title substring> [output-path]
#   screenshot-app.sh workspace <workspace name/number substring> [output-path]
#   screenshot-app.sh list
#
# Unlike a plain `grim` full-screen/output capture, this looks up the
# window or workspace's rect via `swaymsg -t get_tree` and crops to just
# that rect. It's a geometric crop, not real window isolation: if another
# window overlaps that rect, the overlap is captured too.
set -euo pipefail

default_out="$HOME/Pictures/screenshot.png"

usage() {
	cat >&2 <<EOF
Usage:
  $(basename "$0") app <app_id-or-title substring> [output-path]
  $(basename "$0") workspace <name/number substring> [output-path]
  $(basename "$0") list
EOF
	exit 1
}

[ $# -ge 1 ] || usage
mode="$1"
shift

tree="$(swaymsg -t get_tree)"

case "$mode" in
list)
	echo "Windows (app_id / title):"
	echo "$tree" | jq -r '
        [.. | objects | select(.pid? != null)]
        | .[] | "  " + (.app_id // .window_properties.class // "?") + "  —  " + (.name // "")
    '
	echo "Workspaces:"
	echo "$tree" | jq -r '[.. | objects | select(.type? == "workspace")] | .[] | "  " + .name'
	exit 0
	;;
app)
	[ $# -ge 1 ] || usage
	query="$1"
	out="${2:-$default_out}"

	match="$(echo "$tree" | jq -r --arg q "$query" '
        [.. | objects | select(.pid? != null) |
            select(
                ((.app_id // "") | ascii_downcase | contains($q | ascii_downcase)) or
                ((.window_properties.class // "") | ascii_downcase | contains($q | ascii_downcase)) or
                ((.name // "") | ascii_downcase | contains($q | ascii_downcase))
            )
        ] | first // empty
    ')"

	if [ -z "$match" ]; then
		echo "No window matching '$query' found. Try '$(basename "$0") list'." >&2
		exit 1
	fi

	rect="$(echo "$match" | jq -r '"\(.rect.x),\(.rect.y) \(.rect.width)x\(.rect.height)"')"
	;;
workspace)
	[ $# -ge 1 ] || usage
	query="$1"
	out="${2:-$default_out}"

	match="$(echo "$tree" | jq -r --arg q "$query" '
        [.. | objects | select(.type? == "workspace") |
            select((.name // "") | ascii_downcase | contains($q | ascii_downcase))
        ] | first // empty
    ')"

	if [ -z "$match" ]; then
		echo "No workspace matching '$query' found. Try '$(basename "$0") list'." >&2
		exit 1
	fi

	rect="$(echo "$match" | jq -r '"\(.rect.x),\(.rect.y) \(.rect.width)x\(.rect.height)"')"
	;;
*)
	usage
	;;
esac

grim -g "$rect" "$out"
echo "Saved to $out"
