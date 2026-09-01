#!/usr/bin/env bash

display_text=""

while read -r line; do
[ -z "$line" ] && continue

# Extract the MAC address safely from the second column
mac=$(echo "$line" | awk '{print $2}')

info=$(bluetoothctl info "$mac" 2>/dev/null)

if echo "$info" | grep -q "Connected: yes"; then

name=$(echo "$info" | grep "Name:" | cut -d':' -f2- | xargs)

# FIX: Isolate the "Battery" line first, THEN extract the numbers inside the parentheses
battery=$(echo "$info" | grep "Battery Percentage:" | grep -oE '\([0-9]+\)' | tr -d '()')

# Fallback for devices using older BlueZ string structures without parentheses
if [ -z "$battery" ]; then
battery=$(echo "$info" | grep "Battery Percentage:" | grep -oE '[0-9]+' | head -n 1)
fi

# Assign clean hardware type icons
name_lower=$(echo "$name" | tr '[:upper:]' '[:lower:]')
if [[ "$name_lower" =~ "headphone" || "$name_lower" =~ "headset" || "$name_lower" =~ "qc" || "$name_lower" =~ "bose" || "$name_lower" =~ "buds" ]]; then
icon="🎧"
elif [[ "$name_lower" =~ "mouse" ]]; then
icon="🖱️"
elif [[ "$name_lower" =~ "keyboard" ]]; then
icon="⌨️"
else
icon=""
fi

if [ -n "$battery" ]; then
display_text+="$icon $battery%  "
else
display_text+="$icon  "
fi
fi
done < <(bluetoothctl devices)

echo "$display_text" | xargs
