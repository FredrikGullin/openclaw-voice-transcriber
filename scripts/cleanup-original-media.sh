#!/usr/bin/env bash
set -euo pipefail

media_dir="${1:-${OCVT_ORIGINAL_MEDIA_DIR:-$HOME/.openclaw/media/inbound}}"
max_age_minutes="${OCVT_ORIGINAL_MAX_AGE_MINUTES:-60}"

usage() {
  echo "Usage: $0 [/path/to/original-media-dir]" >&2
}

die() {
  echo "$*" >&2
  exit 1
}

[[ "$max_age_minutes" =~ ^[0-9]+$ ]] || die "OCVT_ORIGINAL_MAX_AGE_MINUTES must be a non-negative integer."
[[ -d "$media_dir" ]] || die "Original media directory not found: $media_dir"

case "$(realpath "$media_dir")" in
  / | /home | /home/*/.openclaw | /home/*/.openclaw/media)
    die "Refusing to clean unsafe broad directory: $media_dir"
    ;;
esac

delete_file() {
  local file="$1"

  if [[ "${OCVT_ALLOW_RM_DELETE:-false}" == "true" ]]; then
    rm -f -- "$file"
    return
  fi

  if command -v trash-put >/dev/null 2>&1; then
    trash-put -- "$file"
    return
  fi

  if command -v gio >/dev/null 2>&1; then
    gio trash "$file"
    return
  fi

  die "No trash command found. Install trash-cli/gio or set OCVT_ALLOW_RM_DELETE=true."
}

deleted=0

while IFS= read -r -d '' file; do
  printf 'Deleting old original media: %s\n' "$file"
  delete_file "$file"
  deleted=$((deleted + 1))
done < <(
  find "$media_dir" \
    -maxdepth 1 \
    -type f \
    \( -name '*.ogg' -o -name '*.opus' -o -name '*.m4a' -o -name '*.mp3' -o -name '*.wav' -o -name '*.webm' \) \
    -mmin +"$max_age_minutes" \
    -print0
)

printf 'Original media cleanup complete. Deleted: %s\n' "$deleted"
