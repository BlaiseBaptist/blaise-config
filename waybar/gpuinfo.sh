#!/bin/bash

GPU_UTIL=""
for dev in /sys/class/drm/card*/device; do
    if grep -q "PCI_ID=1002:73FF" "$dev/uevent" 2>/dev/null; then
        GPU_UTIL=$(cat "$dev/gpu_busy_percent")
        break
    fi
done

echo "{\"text\": \"${GPU_UTIL}%\", \"tooltip\": \"GPU Utilization: ${GPU_UTIL}%\"}"
