#!/usr/bin/env bash
# Welcome banner shown once per new terminal window (triggered by tmux's
# session-created hook, see tmux.conf). Two columns: first name (block font)
# on the left, system specs panel on the right, small gap between them, both
# vertically centered against each other. Falls back to a single stacked
# column on terminals too narrow for the two-column layout.

declare -A GLYPH
GLYPH[A]=" ███ |█   █|█████|█   █|█   █"
GLYPH[D]="████ |█   █|█   █|█   █|████ "
GLYPH[E]="█████|█    |████ |█    |█████"
GLYPH[N]="█   █|██  █|█ █ █|█  ██|█   █"
GLYPH[R]="████ |█   █|████ |█  █ |█   █"

render_row() {
    local row="$1" chars="$2" out=""
    local c glyph part
    for ((i = 0; i < ${#chars}; i++)); do
        c="${chars:i:1}"
        glyph="${GLYPH[$c]}"
        IFS='|' read -ra part <<<"$glyph"
        out+="${part[$row]}  "
    done
    printf '%s' "$out"
}

scale_line() {
    local line="$1" scale="$2" out="" ch rep
    for ((i = 0; i < ${#line}; i++)); do
        ch="${line:i:1}"
        printf -v rep '%*s' "$scale" ''
        out+="${rep// /$ch}"
    done
    printf '%s' "$out"
}

char_width() {
    local c="$1"
    echo $(( (${#GLYPH[$c]} - 4) / 5 ))
}

# pad_colored PLAIN_TEXT WIDTH COLOR -> COLOR + text + spaces-to-width + RESET
pad_colored() {
    local text="$1" width="$2" color="$3" fill=$(( width - ${#text} ))
    (( fill < 0 )) && fill=0
    printf '%s%s%*s%s' "$color" "$text" "$fill" "" "$RESET"
}

CYAN=$'\033[1;36m'
RESET=$'\033[0m'
DIM=$'\033[2m'
GREEN=$'\033[1;32m'
YELLOW=$'\033[1;33m'
WHITE=$'\033[1;37m'

cols=$(tput cols)
left_margin=2
gap=4

name_raw="$(git config --global user.name 2>/dev/null)"
[ -z "$name_raw" ] && name_raw="$USER"
name_raw="${name_raw%% *}"
name_upper=$(printf '%s' "$name_raw" | tr '[:lower:]' '[:upper:]')

base_width=0
for ((i = 0; i < ${#name_upper}; i++)); do
    c="${name_upper:i:1}"
    base_width=$(( base_width + $(char_width "$c") + 2 ))
done

# ---- gather system info ----

if [ -d /sys/class/power_supply/BAT0 ]; then
    batt_pct=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)
    batt_status=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null)
    case "$batt_status" in
        Full) batt_status="Fully charged" ;;
        Charging) batt_status="Charging" ;;
        Discharging) batt_status="Discharging" ;;
    esac
    battery="${batt_pct}% (${batt_status})"
else
    battery="N/A"
fi

mem_line=$(free -m | awk '/^Mem:/ {printf "%.1fG / %.1fG (%d%%)", $3/1024, $2/1024, ($3/$2)*100}')
disk_line=$(df -h --output=used,size,pcent / | tail -1 | awk '{print $1" / "$2" ("$3")"}')
cpu_avg=$(sensors 2>/dev/null | awk '/^Core [0-9]+:/ { gsub("\\+",""); gsub("°C",""); sum+=$3; count++ } END { if (count>0) printf "%.1f\xc2\xb0C", sum/count; else print "N/A" }')
uptime_str=$(uptime -p 2>/dev/null | sed 's/^up //')

# checkupdates (pacman-contrib) checks a private copy of the sync db, so
# this never touches the system db or needs root — --nosync keeps it fast
# since this runs on every new terminal window, reading whatever pacman
# last synced rather than hitting the network each time.
if command -v checkupdates &>/dev/null; then
    updates=$(checkupdates --nosync 2>/dev/null | wc -l)
else
    updates=0
fi
if [ "$updates" -gt 0 ] 2>/dev/null; then
    updates_line="⚠ ${updates} update(s) available"
    updates_color="$YELLOW"
else
    updates_line="✓ System up to date"
    updates_color="$GREEN"
fi

info_rows=(
    "Battery|$battery|$WHITE"
    "Memory|$mem_line|$WHITE"
    "Disk|$disk_line|$WHITE"
    "CPU Temp (avg)|$cpu_avg|$WHITE"
    "Uptime|$uptime_str|$WHITE"
    "Updates|$updates_line|$updates_color"
)

label_width=0
value_width=0
for r in "${info_rows[@]}"; do
    IFS='|' read -r label value _ <<<"$r"
    (( ${#label} > label_width )) && label_width=${#label}
    (( ${#value} > value_width )) && value_width=${#value}
done
right_content_width=$(( label_width + 2 + value_width ))
right_col_width=$(( right_content_width + 4 ))
right_inner=$(( right_col_width - 2 ))
right_text_width=$(( right_inner - 2 ))

build_right_lines() {
    local hline
    hline=$(printf '─%.0s' $(seq 1 $right_inner))
    right_lines=("${DIM}╭${hline}╮${RESET}")
    local r label value color plain fill
    for r in "${info_rows[@]}"; do
        IFS='|' read -r label value color <<<"$r"
        plain=$(printf "%-${label_width}s  %s" "$label" "$value")
        fill=$(( right_text_width - ${#plain} ))
        (( fill < 0 )) && fill=0
        right_lines+=("${DIM}│${RESET} ${WHITE}$(printf "%-${label_width}s" "$label")${RESET}  ${color}${value}${RESET}$(printf '%*s' "$fill" "") ${DIM}│${RESET}")
    done
    right_lines+=("${DIM}╰${hline}╯${RESET}")
}

# build_left_lines_stretch TARGET_HEIGHT -> fills left_lines[] with exactly
# TARGET_HEIGHT rows, nearest-neighbor-stretching the 5-row glyph to match
# (so the name spans the same height as the info table, no gaps).
build_left_lines_stretch() {
    local target="$1"
    local left_w=$base_width
    (( ${#name_raw} > left_w )) && left_w=${#name_raw}
    left_col_width=$left_w
    left_lines=()
    local i src rawrow
    for ((i = 0; i < target; i++)); do
        src=$(( i * 5 / target ))
        (( src > 4 )) && src=4
        rawrow=$(render_row "$src" "$name_upper")
        left_lines+=("$(pad_colored "$rawrow" "$left_col_width" "$CYAN")")
    done
}

echo

required_scale1=$(( left_margin + base_width + gap + right_col_width ))
if (( base_width > 0 && cols >= required_scale1 )); then
    build_right_lines
    right_h=${#right_lines[@]}
    build_left_lines_stretch "$right_h"

    for ((i = 0; i < right_h; i++)); do
        printf '%*s%s%*s%s\n' "$left_margin" "" "${left_lines[$i]}" "$gap" "" "${right_lines[$i]}"
    done
else
    # Too narrow for two columns: fall back to a single centered column.
    if (( base_width > cols )); then
        pad_name=$(( (cols - ${#name_raw}) / 2 ))
        (( pad_name < 0 )) && pad_name=0
        printf '%*s%s%s%s\n' "$pad_name" "" "$CYAN" "$name_raw" "$RESET"
    else
        pad_name=$(( (cols - base_width) / 2 ))
        (( pad_name < 0 )) && pad_name=0
        for row in 0 1 2 3 4; do
            rawrow=$(render_row "$row" "$name_upper")
            printf '%*s%s%s%s\n' "$pad_name" "" "$CYAN" "$rawrow" "$RESET"
        done
    fi
    echo

    build_right_lines
    pad_box=$(( (cols - right_col_width) / 2 ))
    (( pad_box < 0 )) && pad_box=0
    for line in "${right_lines[@]}"; do
        printf '%*s%s\n' "$pad_box" "" "$line"
    done
fi
echo
