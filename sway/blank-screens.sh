#!/bin/sh
# Blank every output until the next input event.
#
# `output * dpms off` is sticky: sway does NOT undo it when input arrives, so a
# manual blank with nothing watching leaves the screens dark until the swayidle
# daemon's own timeout/resume cycle happens to fire (up to ~5 minutes later).
# This starts a throwaway swayidle whose only job is to turn the outputs back on
# at the first sign of input, then exit — $$ survives the exec, so the resume
# command can kill the very swayidle that ran it.
#
# The immediate dpms off is what makes the key feel instant; the `timeout 1`
# blank is the same thing again (harmless) and exists so the watcher is
# guaranteed to reach the idle state that arms `resume`.
# Never blank without a working way back: if swayidle is missing there is
# nothing to run `dpms on`, and the screens would stay dark.
command -v swayidle >/dev/null || exit 1
swaymsg "output * dpms off"
#
# before-sleep ends it too: its job is over once the machine suspends, and a
# leftover blanker must not be around after wake re-blanking what
# wake-outputs.sh just turned on. It powers the outputs back on first: killing
# it bare left `output * dpms off` stored in sway's config, which every output
# recreated on resume inherits (the 2026-09-25 19:24 black screen). The session
# is already locked, so this only lights the lock screen for the moment before
# suspend.
exec swayidle -w \
	timeout 1 'swaymsg "output * dpms off"' \
	resume "swaymsg 'output * dpms on'; kill $$" \
	before-sleep "swaymsg 'output * dpms on'; kill $$"
