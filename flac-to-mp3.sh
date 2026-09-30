#!/usr/bin/env bash
# Конвертира FLAC в MP3 (320 kbps), включително в подпапките.
# Употреба: bash flac-to-mp3.sh [папка]
set -uo pipefail

if ! command -v ffmpeg >/dev/null 2>&1; then
    printf 'Грешка: инсталирай ffmpeg (в Ubuntu/Debian: sudo apt install ffmpeg).\n' >&2
    exit 1
fi

folder="${1:-.}"
if [[ ! -d "$folder" ]]; then
    printf 'Няма такава папка: %s\n' "$folder" >&2
    exit 1
fi
folder=$(cd -- "$folder" && pwd) || exit 1

temporary=''
cleanup() {
    [[ -z "$temporary" ]] || rm -f -- "$temporary"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

converted=0
skipped=0
failed=0
while IFS= read -r -d '' source; do
    destination="${source%.*}.mp3"
    if [[ -e "$destination" || -L "$destination" ]]; then
        printf 'Пропускам съществуващ файл: %s\n' "$destination"
        skipped=$((skipped + 1))
        continue
    fi

    printf 'Конвертирам: %s\n' "$source"
    temporary=$(mktemp -- "${destination}.tmp.XXXXXXXX.mp3") || exit 1
    if ffmpeg -nostdin -hide_banner -loglevel error -y \
        -i "$source" \
        -map 0:a:0 -map '0:v:0?' -map_metadata 0 \
        -c:a libmp3lame -b:a 320k -compression_level 0 \
        -c:v mjpeg -disposition:v:0 attached_pic \
        -id3v2_version 3 -f mp3 "$temporary"; then
        # Hard link публикува готовия файл без презаписване на съществуващ MP3.
        if ln -- "$temporary" "$destination"; then
            converted=$((converted + 1))
        else
            printf 'Не успях да запазя: %s\n' "$destination" >&2
            failed=$((failed + 1))
        fi
    else
        printf 'Неуспешна конверсия: %s\n' "$source" >&2
        failed=$((failed + 1))
    fi
    cleanup
    temporary=''
done < <(find "$folder" -type f -iname '*.flac' -print0)

printf '\nГотово: %d конвертирани, %d пропуснати, %d неуспешни.\n' \
    "$converted" "$skipped" "$failed"
[[ "$failed" -eq 0 ]]
