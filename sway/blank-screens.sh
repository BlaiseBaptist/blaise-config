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
exec swayidle -w \
	timeout 1 'swaymsg "output * dpms off"' \
	resume "swaymsg 'output * dpms on'; kill $$"
