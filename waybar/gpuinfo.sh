#!/bin/bash

GPU_UTIL=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits)

# You can customize the output format here.
# For example, to include an icon and a tooltip:
echo "{\"text\": \"${GPU_UTIL}%\", \"tooltip\": \"GPU Utilization: ${GPU_UTIL}%\"}"
