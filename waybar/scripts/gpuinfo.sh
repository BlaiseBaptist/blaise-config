#!/bin/bash

# Waybar runs this every second. Calling nvidia-smi wakes the dGPU, so doing it
# every second keeps the dGPU from ever runtime-suspending. Read the power
# state from sysfs instead (that doesn't wake it), and only query utilization
# while the GPU is already awake, at most once every QUERY_EVERY seconds so it
# can still go idle between queries.
DEV=/sys/bus/pci/devices/0000:01:00.0
QUERY_EVERY=10
CACHE="${XDG_RUNTIME_DIR:-/tmp}/waybar-gpuinfo"

STATE=$(cat "$DEV/power/runtime_status" 2>/dev/null)

if [ "$STATE" != "active" ]; then
	echo "{\"text\": \"off\", \"tooltip\": \"NVIDIA GPU: ${STATE:-unknown}\", \"class\": \"off\"}"
	exit 0
fi

now=$(date +%s)
if [ -f "$CACHE" ] && [ $((now - $(stat -c %Y "$CACHE"))) -lt $QUERY_EVERY ]; then
	GPU_UTIL=$(cat "$CACHE")
else
	GPU_UTIL=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits)
	echo "$GPU_UTIL" > "$CACHE"
fi

echo "{\"text\": \"${GPU_UTIL}%\", \"tooltip\": \"GPU Utilization: ${GPU_UTIL}%\"}"
