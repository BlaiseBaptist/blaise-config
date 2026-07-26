#!/usr/bin/env bash
# Screenshot a single app window or a whole workspace on Sway, by name.
#
# Usage:
#   screenshot-app.sh app <name> <app_id-or-title substring> [output-path]
#   screenshot-app.sh workspace <name> <workspace name/number substring> [output-path]
#   screenshot-app.sh list
#
# <name> is a required tag for this capture (e.g. an agent/task id). It
# picks the default output file (~/Pictures/screenshot-<name>.png) so
# concurrent callers never share a path — no defaulting to the same
# screenshot.png the user's own $mod+F7 capture and other callers use.
#
# "app" mode uses wayshot's ext-image-copy-capture-based toplevel capture
# (wayshot-git — the stable 1.5.0 release can't be scripted, it lacks
# --list-toplevels-json). This captures a window's actual buffer
# regardless of occlusion or which workspace it's on — no workspace
# switch, no flicker, no interrupting the user.
#
# "workspace" mode has no equivalent off-screen protocol (workspaces
# aren't toplevels), so it still only works when the workspace is
# already visible and errors out otherwise rather than switching to it.
set -euo pipefail

usage() {
	cat >&2 <<EOF
Usage:
  $(basename "$0") app <name> <app_id-or-title substring> [output-path]
  $(basename "$0") workspace <name> <name/number substring> [output-path]
  $(basename "$0") list
EOF
	exit 1
}

[ $# -ge 1 ] || usage
mode="$1"
shift

if [ "$mode" = list ]; then
	echo "Windows (app_id / title):"
	wayshot --list-toplevels-json | jq -r '.[] | "  " + (.app_id // "?") + "  —  " + .title'
	echo "Workspaces:"
	swaymsg -t get_tree | jq -r '[.. | objects | select(.type? == "workspace")] | .[] | "  " + .name'
	exit 0
fi

[ "$mode" = app ] || [ "$mode" = workspace ] || usage
[ $# -ge 2 ] || usage
name="$1"
query="$2"
out="${3:-$HOME/Pictures/screenshot-$name.png}"

if [ "$mode" = app ]; then
	match="$(wayshot --list-toplevels-json | jq -r --arg q "$query" '
        [.[] |
            select(
                ((.app_id // "") | ascii_downcase | contains($q | ascii_downcase)) or
                ((.title // "") | ascii_downcase | contains($q | ascii_downcase))
            )
        ] | first // empty
    ')"

	if [ -z "$match" ]; then
		echo "No window matching '$query' found. Try '$(basename "$0") list'." >&2
		exit 1
	fi

	identifier="$(echo "$match" | jq -r '.identifier')"
	wayshot --toplevel "$identifier" "$out"
else
	tree="$(swaymsg -t get_tree)"
	match="$(echo "$tree" | jq -r --arg q "$query" '
        [.. | objects | select(.type? == "workspace") |
            select((.name // "") | ascii_downcase | contains($q | ascii_downcase))
        ] | first // empty
    ')"

	if [ -z "$match" ]; then
		echo "No workspace matching '$query' found. Try '$(basename "$0") list'." >&2
		exit 1
	fi

	target_ws="$(echo "$match" | jq -r '.name')"
	target_visible="$(swaymsg -t get_workspaces | jq -r --arg w "$target_ws" '.[] | select(.name == $w) | .visible')"
	if [ "$target_visible" != "true" ]; then
		echo "'$target_ws' isn't currently visible — switch to it first (this tool never changes your active workspace)." >&2
		exit 1
	fi

	rect="$(echo "$match" | jq -r '"\(.rect.x),\(.rect.y) \(.rect.width)x\(.rect.height)"')"
	grim -g "$rect" "$out"
fi

echo "Saved to $out"
