#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$root_dir/scripts/cleanup-original-media.sh"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

media_dir="$tmp_root/inbound"
mkdir -p "$media_dir"

old_ogg="$media_dir/old.ogg"
old_wav="$media_dir/old.wav"
fresh_ogg="$media_dir/fresh.ogg"
old_txt="$media_dir/old.txt"

printf 'old ogg\n' >"$old_ogg"
printf 'old wav\n' >"$old_wav"
printf 'fresh ogg\n' >"$fresh_ogg"
printf 'old text\n' >"$old_txt"

touch -d '2 hours ago' "$old_ogg" "$old_wav" "$old_txt"

output="$(
  OCVT_ORIGINAL_MAX_AGE_MINUTES=60 \
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

echo "Retention cleanup checks passed."
