#!/usr/bin/env bash
# Called by Noctalia's battery_percentage_changed hook.
# Fires once when crossing below 20% (warning) and 10% (critical) while discharging.
set -euo pipefail

percent="${NOCTALIA_BATTERY_PERCENT:-}"
bstate="${NOCTALIA_BATTERY_STATE:-unknown}"
[[ "$percent" =~ ^[0-9]+$ ]] || exit 0

dir="${XDG_STATE_HOME:-$HOME/.local/state}/idle-kit"
mkdir -p "$dir"
prev=""; [[ -r "$dir/battery-percent" ]] && prev="$(<"$dir/battery-percent")"
printf '%s\n' "$percent" > "$dir/battery-percent"

[[ "$bstate" == discharging ]] || exit 0
[[ "$prev" =~ ^[0-9]+$ ]] || exit 0

if (( prev >= 10 && percent < 10 )); then
  notify-send -u critical -i battery-caution "Battery critically low" \
    "${percent}% left. The system will hibernate/shut down at 4%. Plug in now."
elif (( prev >= 20 && percent < 20 )); then
  notify-send -u normal -i battery-low "Battery low" \
    "${percent}% left. Plug in soon."
fi
