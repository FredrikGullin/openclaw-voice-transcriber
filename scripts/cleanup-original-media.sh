#!/usr/bin/env bash
set -euo pipefail

media_dir="${1:-${OCVT_ORIGINAL_MEDIA_DIR:-$HOME/.openclaw/media/inbound}}"
max_age_minutes="${OCVT_ORIGINAL_MAX_AGE_MINUTES:-60}"
trash_max_age_minutes="${OCVT_TRASH_MAX_AGE_MINUTES:-1440}"
trash_root="${OCVT_TRASH_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/Trash}"

usage() {
  echo "Usage: $0 [/path/to/original-media-dir]" >&2
}

die() {
  echo "$*" >&2
  exit 1
}

[[ "$max_age_minutes" =~ ^[0-9]+$ ]] || die "OCVT_ORIGINAL_MAX_AGE_MINUTES must be a non-negative integer."
[[ "$trash_max_age_minutes" =~ ^[0-9]+$ ]] || die "OCVT_TRASH_MAX_AGE_MINUTES must be a non-negative integer."
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

purge_trash() {
  local trash_files_dir="$trash_root/files"
  local trash_info_dir="$trash_root/info"
  local now_epoch deletion_date deletion_epoch age_seconds
  local info_file original_path trash_name trashed_file
  local purged=0

  if [[ ! -d "$trash_files_dir" || ! -d "$trash_info_dir" ]]; then
    printf 'Trash purge skipped. Trash directory not found: %s\n' "$trash_root"
    return
  fi

  case "$(realpath "$trash_root")" in
    / | /home | /home/* | /tmp | /tmp/*)
      case "$(realpath "$trash_root")" in
        */Trash) ;;
        *) die "Refusing to purge unsafe trash directory: $trash_root" ;;
      esac
      ;;
  esac

  now_epoch="$(date +%s)"

  while IFS= read -r -d '' info_file; do
    original_path="$(sed -n 's/^Path=//p' "$info_file" | head -n 1)"
    deletion_date="$(sed -n 's/^DeletionDate=//p' "$info_file" | head -n 1)"

    [[ -n "$original_path" && -n "$deletion_date" ]] || continue
    [[ "$original_path" == "$(realpath "$media_dir")"/* ]] || continue

    case "$original_path" in
      *.ogg | *.opus | *.m4a | *.mp3 | *.wav | *.webm) ;;
      *) continue ;;
    esac

    deletion_epoch="$(date -d "$deletion_date" +%s 2>/dev/null || true)"
    [[ -n "$deletion_epoch" ]] || continue

    age_seconds=$((now_epoch - deletion_epoch))
    (( age_seconds > trash_max_age_minutes * 60 )) || continue

    trash_name="$(basename "$info_file" .trashinfo)"
    trashed_file="$trash_files_dir/$trash_name"

    printf 'Purging old original media from trash: %s\n' "$original_path"
    rm -rf -- "$trashed_file"
    rm -f -- "$info_file"
    purged=$((purged + 1))
  done < <(
    find "$trash_info_dir" -maxdepth 1 -type f -name '*.trashinfo' -print0
  )

  printf 'Trash purge complete. Purged: %s\n' "$purged"
}

purge_trash
