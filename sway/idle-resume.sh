#!/bin/sh
# swayidle's resume: turn the outputs back on after the idle blank, but leave
# eDP-1 off while the lid is closed.
#
# Closing the lid is input activity, so if the idle timeout had already blanked
# the screens, the lid close itself fires this. A bare `output * dpms on` then
# re-lights eDP-1 a few ms after `bindswitch lid:on` turned it off, and the
# laptop suspends with the panel scanning out. sway can't shut that CRTC down
# once the session is paused for sleep, and on wake every eDP-1 modeset fails
# with EINVAL: wake-outputs.sh gets `success` from sway and a black screen
# (2026-09-30 23:19, 2026-10-12 08:58: idle blank while docked, pull the dock,
# close the lid). Opening the lid still lights it via `bindswitch lid:off`.
lid_closed() { grep -q closed /proc/acpi/button/lid/*/state 2>/dev/null; }

if lid_closed; then
	# `output *` overrides eDP-1's own config, so it has to be turned off again
	# after the wildcard, in the same swaymsg so nothing runs in between.
	swaymsg "output * dpms off; output * dpms on; output eDP-1 dpms off"
else
	swaymsg "output * dpms off" && swaymsg "output * dpms on"
fi
