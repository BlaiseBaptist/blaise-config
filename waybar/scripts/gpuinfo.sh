#!/bin/bash

# With a PCI address argument (e.g. 0000:03:00.0), report that amdgpu card's
# utilization straight from sysfs, which is cheap and doesn't wake anything.
if [ -n "$1" ]; then
	GPU_UTIL=$(cat "/sys/bus/pci/devices/$1/gpu_busy_percent" 2>/dev/null)
	echo "{\"text\": \"${GPU_UTIL:-?}%\", \"tooltip\": \"GPU Utilization: ${GPU_UTIL:-unknown}%\"}"
	exit 0
fi

# No argument: the archlinux NVIDIA dGPU.
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

# nvidia-idle-off.service unloads the driver when the dGPU is idle so it can
# power off. nvidia-smi would load it straight back (via nvidia-modprobe), so
# never call it while the driver is unloaded; the card is off or about to be.
if [ ! -d /sys/module/nvidia ]; then
	echo "{\"text\": \"off\", \"tooltip\": \"NVIDIA GPU: driver unloaded (${STATE})\", \"class\": \"off\"}"
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
