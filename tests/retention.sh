#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$root_dir/scripts/cleanup-original-media.sh"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

media_dir="$tmp_root/inbound"
trash_root="$tmp_root/Trash"
mkdir -p "$media_dir"
mkdir -p "$trash_root/files" "$trash_root/info"

old_ogg="$media_dir/old.ogg"
old_wav="$media_dir/old.wav"
fresh_ogg="$media_dir/fresh.ogg"
old_txt="$media_dir/old.txt"
trashed_old="$trash_root/files/old-trash.ogg"
trashed_fresh="$trash_root/files/fresh-trash.ogg"
trashed_other="$trash_root/files/other-project.ogg"

printf 'old ogg\n' >"$old_ogg"
printf 'old wav\n' >"$old_wav"
printf 'fresh ogg\n' >"$fresh_ogg"
printf 'old text\n' >"$old_txt"

touch -d '2 hours ago' "$old_ogg" "$old_wav" "$old_txt"

printf 'old trashed ogg\n' >"$trashed_old"
printf 'fresh trashed ogg\n' >"$trashed_fresh"
printf 'other trashed ogg\n' >"$trashed_other"

cat >"$trash_root/info/old-trash.ogg.trashinfo" <<EOF
[Trash Info]
Path=$media_dir/old-trash.ogg
DeletionDate=$(date -d '2 days ago' '+%Y-%m-%dT%H:%M:%S')
EOF

cat >"$trash_root/info/fresh-trash.ogg.trashinfo" <<EOF
[Trash Info]
Path=$media_dir/fresh-trash.ogg
DeletionDate=$(date -d '10 minutes ago' '+%Y-%m-%dT%H:%M:%S')
EOF

cat >"$trash_root/info/other-project.ogg.trashinfo" <<EOF
[Trash Info]
Path=$tmp_root/other/other-project.ogg
DeletionDate=$(date -d '2 days ago' '+%Y-%m-%dT%H:%M:%S')
EOF

output="$(
  OCVT_ORIGINAL_MAX_AGE_MINUTES=60 \
  OCVT_TRASH_MAX_AGE_MINUTES=1440 \
  OCVT_TRASH_DIR="$trash_root" \
  OCVT_ALLOW_RM_DELETE=true \
  "$script" "$media_dir"
)"

[[ ! -e "$old_ogg" ]] || {
  echo "$output" >&2
  echo "FAIL: old .ogg was not deleted" >&2
  exit 1
}

[[ ! -e "$old_wav" ]] || {
  echo "$output" >&2
  echo "FAIL: old .wav was not deleted" >&2
  exit 1
}

[[ -e "$fresh_ogg" ]] || {
  echo "$output" >&2
  echo "FAIL: fresh .ogg was deleted" >&2
  exit 1
}

[[ -e "$old_txt" ]] || {
  echo "$output" >&2
  echo "FAIL: non-media .txt was deleted" >&2
  exit 1
}

grep -Fq "Original media cleanup complete. Deleted: 2" <<<"$output" || {
  echo "$output" >&2
  echo "FAIL: unexpected cleanup summary" >&2
  exit 1
}

[[ ! -e "$trashed_old" && ! -e "$trash_root/info/old-trash.ogg.trashinfo" ]] || {
  echo "$output" >&2
  echo "FAIL: old transcriber trash was not purged" >&2
  exit 1
}

[[ -e "$trashed_fresh" && -e "$trash_root/info/fresh-trash.ogg.trashinfo" ]] || {
  echo "$output" >&2
  echo "FAIL: fresh transcriber trash was purged" >&2
  exit 1
}

[[ -e "$trashed_other" && -e "$trash_root/info/other-project.ogg.trashinfo" ]] || {
  echo "$output" >&2
  echo "FAIL: unrelated trash was purged" >&2
  exit 1
}

grep -Fq "Trash purge complete. Purged: 1" <<<"$output" || {
  echo "$output" >&2
  echo "FAIL: unexpected trash purge summary" >&2
  exit 1
}

echo "Retention cleanup checks passed."
