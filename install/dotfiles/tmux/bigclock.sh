#!/usr/bin/env bash
# Big 12-hour clock for a tmux popup: HH:MM big, AM/PM at half that size next
# to it, day/date at half the AM/PM size below. Whole composition is
# centered as one block. Refreshes every second. Press any key to close.

trap 'tput cnorm; clear' EXIT
tput civis

declare -A GLYPH
GLYPH[0]=" ███ |█   █|█   █|█   █| ███ "
GLYPH[1]="  █  | ██  |  █  |  █  | ███ "
GLYPH[2]=" ███ |█   █|   █ |  █  |█████"
GLYPH[3]=" ███ |█   █|  ██ |█   █| ███ "
GLYPH[4]="█   █|█   █|█████|    █|    █"
GLYPH[5]="█████|█    |████ |    █|████ "
GLYPH[6]=" ███ |█    |████ |█   █| ███ "
GLYPH[7]="█████|   █ |  █  | █   |█    "
GLYPH[8]=" ███ |█   █| ███ |█   █| ███ "
GLYPH[9]=" ███ |█   █| ████|    █| ███ "
GLYPH[:]="   |   | █ |   | █ "
GLYPH[A]=" ███ |█   █|█████|█   █|█   █"
GLYPH[M]="█   █|██ ██|█ █ █|█   █|█   █"
GLYPH[P]="████ |█   █|████ |█    |█    "

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

# Builds $scale*5 lines of a glyph string into the array named by $3.
build_block() {
    local chars="$1" scl="$2" __arrname="$3"
    local -n __arr="$__arrname"
    __arr=()
    for base_row in 0 1 2 3 4; do
        local rawrow scaledrow
        rawrow=$(render_row "$base_row" "$chars")
        scaledrow=$(scale_line "$rawrow" "$scl")
        for ((r = 0; r < scl; r++)); do
            __arr+=("$scaledrow")
        done
    done
}

char_width() {
    local c="$1"
    echo $(( (${#GLYPH[$c]} - 4) / 5 ))
}

block_width() {
    local chars="$1" scl="$2" w=0 c
    for ((i = 0; i < ${#chars}; i++)); do
        c="${chars:i:1}"
        w=$(( w + ($(char_width "$c") + 2) * scl ))
    done
    echo "$w"
}

while true; do
    time_str=$(date '+%I:%M')
    ampm=$(date '+%p')
    datebottom=$(date '+%A, %B %d %Y')

    cols=$(tput cols)
    lines=$(tput lines)

    base_width=0
    for ((i = 0; i < ${#time_str}; i++)); do
        c="${time_str:i:1}"
        base_width=$(( base_width + $(char_width "$c") + 2 ))
    done

    scale=$(( cols / (base_width + 10) ))
    (( scale < 1 )) && scale=1
    lines_scale=$(( (lines - 10) / 5 ))
    (( lines_scale < 1 )) && lines_scale=1
    (( scale > lines_scale )) && scale=$lines_scale
    (( scale > 6 )) && scale=6

    ampm_scale=$(( scale / 2 ))
    (( ampm_scale < 1 )) && ampm_scale=1

    time_width=$(( base_width * scale ))
    ampm_width=$(block_width "$ampm" "$ampm_scale")
    gap=$(( scale ))
    top_width=$(( time_width + gap + ampm_width ))
    pad_top=$(( (cols - top_width) / 2 ))
    (( pad_top < 0 )) && pad_top=0

    pad_date=$(( (cols - ${#datebottom}) / 2 ))
    (( pad_date < 0 )) && pad_date=0

    top_height=$(( 5 * scale ))
    date_height=1
    date_gap=$(( scale / 2 + 2 ))
    total_height=$(( top_height + date_gap + date_height ))
    vpad=$(( (lines - total_height) / 2 ))
    (( vpad < 0 )) && vpad=0

    build_block "$time_str" "$scale" time_lines
    build_block "$ampm" "$ampm_scale" ampm_lines

    ampm_height=$(( 5 * ampm_scale ))
    ampm_offset=$(( (top_height - ampm_height) / 2 ))

    clear
    for ((v = 0; v < vpad; v++)); do echo; done
    for ((row = 0; row < top_height; row++)); do
        printf '%*s%s' "$pad_top" "" "${time_lines[$row]}"
        if (( row >= ampm_offset && row < ampm_offset + ampm_height )); then
            printf '%*s%s' "$gap" "" "${ampm_lines[$((row - ampm_offset))]}"
        fi
        printf '\n'
    done
    for ((v = 0; v < date_gap; v++)); do echo; done
    printf '%*s%s\n' "$pad_date" "" "$datebottom"

    if read -t 1 -n 1 -s; then
        break
    fi
done
