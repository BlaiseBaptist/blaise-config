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
# Capture is also serialized with flock, since the workspace-switch step
# below is a global side effect: two callers switching workspaces at once
# would race visually even with distinct output files.
#
# Unlike a plain `grim` full-screen/output capture, this looks up the
# window or workspace's rect via `swaymsg -t get_tree` and crops to just
# that rect. It's a geometric crop, not real window isolation: if another
# window overlaps that rect, the overlap is captured too.
#
# Sway only renders the workspace currently visible on each output, so a
# window on a hidden workspace can't be captured without switching to it
# first. When that's needed, this briefly switches to the target
# workspace, screenshots, then switches back to whatever workspace was
# focused before — so the net effect is that focus doesn't move.
set -euo pipefail

lockfile="/tmp/screenshot-app.lock"

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
	tree="$(swaymsg -t get_tree)"
	echo "Windows (app_id / title):"
	echo "$tree" | jq -r '
        [.. | objects | select(.pid? != null)]
        | .[] | "  " + (.app_id // .window_properties.class // "?") + "  —  " + (.name // "")
    '
	echo "Workspaces:"
	echo "$tree" | jq -r '[.. | objects | select(.type? == "workspace")] | .[] | "  " + .name'
	exit 0
fi

[ "$mode" = app ] || [ "$mode" = workspace ] || usage
[ $# -ge 2 ] || usage
name="$1"
query="$2"
out="${3:-$HOME/Pictures/screenshot-$name.png}"

# Everything past this point touches shared compositor state (focused
# workspace), so only one invocation runs it at a time.
exec 9>"$lockfile"
flock 9

tree="$(swaymsg -t get_tree)"

if [ "$mode" = app ]; then
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

	con_id="$(echo "$match" | jq -r '.id')"
	target_ws="$(echo "$tree" | jq -r --argjson id "$con_id" '
        [.. | objects | select(.type == "workspace") |
            select([.. | objects | .id?] | any(. == $id))
        ] | first | .name
    ')"
else
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
fi

workspaces="$(swaymsg -t get_workspaces)"
orig_ws="$(echo "$workspaces" | jq -r '.[] | select(.focused) | .name')"
target_visible="$(echo "$workspaces" | jq -r --arg w "$target_ws" '.[] | select(.name == $w) | .visible')"

switched=false
if [ "$target_visible" != "true" ]; then
	swaymsg -q workspace "$target_ws"
	switched=true
fi

restore() {
	if [ "$switched" = true ]; then
		swaymsg -q workspace "$orig_ws"
	fi
}
trap restore EXIT

# Re-fetch the tree: a workspace switch can change rects (e.g. layout
# reflow), and for "app" mode we need the window's rect specifically.
tree="$(swaymsg -t get_tree)"
if [ "$mode" = app ]; then
	rect="$(echo "$tree" | jq -r --argjson id "$con_id" '
        [.. | objects | select(.id? == $id)] | first
        | "\(.rect.x),\(.rect.y) \(.rect.width)x\(.rect.height)"
    ')"
else
	rect="$(echo "$tree" | jq -r --arg w "$target_ws" '
        [.. | objects | select(.type == "workspace" and .name == $w)] | first
        | "\(.rect.x),\(.rect.y) \(.rect.width)x\(.rect.height)"
    ')"
fi

grim -g "$rect" "$out"
echo "Saved to $out"
