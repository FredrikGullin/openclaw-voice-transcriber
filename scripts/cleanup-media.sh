#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="${OCVT_TMP_DIR:-$root_dir/.local/tmp}"
max_age_minutes="${OCVT_CLEANUP_MAX_AGE_MINUTES:-1440}"

if [[ ! -d "$tmp_dir" ]]; then
  echo "No temporary directory found: $tmp_dir"
  exit 0
fi

find "$tmp_dir" -type f \( -name '*.wav' -o -name '*.ogg' -o -name '*.txt' \) -mmin +"$max_age_minutes" -print -delete
