#!/bin/sh
# Live target for the first Thinkfan fan level. The root cpu-profile-limits
# daemon reads this runtime setting and shifts its filtered sensor values.
set -eu

target_file=/run/cpu-profile-limits/fan_start_temp
minimum=30
maximum=80
step=1
scroll_divisor=4

read_target() {
    value=$(cat "$target_file" 2>/dev/null || printf '52')
    case "$value" in *[!0-9]*|'') value=52 ;; esac
    [ "$value" -ge "$minimum" ] || value=$minimum
    [ "$value" -le "$maximum" ] || value=$maximum
    printf '%s' "$value"
}

set_target() {
    value=$1
    [ "$value" -ge "$minimum" ] || value=$minimum
    [ "$value" -le "$maximum" ] || value=$maximum
    printf '%s\n' "$value" > "$target_file"
}

case "${1:-show}" in
    up|down)
        # Waybar starts one process per wheel event. Accumulate four events
        # per direction before applying a 1°C change (25% sensitivity).
        state_dir=${XDG_RUNTIME_DIR:?Waybar must set XDG_RUNTIME_DIR}
        mkdir -p "$state_dir/cpu-power-tuning"
        counter_file="$state_dir/cpu-power-tuning/fan-scroll-$1"
        exec 9>"$counter_file.lock"
        flock -x 9
        count=$(cat "$counter_file" 2>/dev/null || printf '0')
        case "$count" in *[!0-9]*|'') count=0 ;; esac
        count=$((count + 1))
        if [ "$count" -ge "$scroll_divisor" ]; then
            current=$(read_target)
            if [ "$1" = up ]; then current=$((current + step)); else current=$((current - step)); fi
            set_target "$current"
            count=0
        fi
        printf '%s\n' "$count" > "$counter_file"
        ;;
    set-65)
        set_target 65
        ;;
    show)
        current=$(read_target)
        printf '{"text":"󰈐 %s°","tooltip":"Target temp: %s°C"}\n' \
            "$current" "$current"
        ;;
    *) exit 2 ;;
esac
