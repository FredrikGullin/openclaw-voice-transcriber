#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/audio.ogg" >&2
  exit 2
fi

input_file="$1"
test -f "$input_file" || {
  echo "Input file not found: $input_file" >&2
  exit 1
}

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
local_dir="$root_dir/.local"
tmp_dir="${OCVT_TMP_DIR:-$local_dir/tmp}"
model_path="${OCVT_MODEL_PATH:-$local_dir/models/ggml-small.bin}"
language="${OCVT_LANGUAGE:-auto}"
keep_artifacts="${OCVT_KEEP_ARTIFACTS:-false}"

mkdir -p "$tmp_dir"

find_whisper_cli() {
  local candidates=(
    "$local_dir/whisper.cpp/build/bin/whisper-cli"
    "$local_dir/whisper.cpp/build/bin/main"
    "$local_dir/whisper.cpp/main"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

whisper_cli="$(find_whisper_cli)" || {
  echo "whisper.cpp binary not found. Run: make setup" >&2
  exit 1
}

test -f "$model_path" || {
  echo "Model file not found: $model_path" >&2
  echo "Run: make setup" >&2
  exit 1
}

base_name="$(basename "$input_file")"
stamp="$(date +%Y%m%d-%H%M%S)"
work_prefix="$tmp_dir/${stamp}-${base_name%.*}"
wav_file="$work_prefix.wav"
output_prefix="$work_prefix"
output_txt="$output_prefix.txt"
output_log="$output_prefix.log"

cleanup() {
  rm -f "$wav_file"
  if [[ "$keep_artifacts" != "true" ]]; then
    rm -f "$output_txt" "$output_log"
  fi
}
trap cleanup EXIT

ffmpeg -hide_banner -loglevel error -y -i "$input_file" -ar 16000 -ac 1 -c:a pcm_s16le "$wav_file"

if ! "$whisper_cli" \
  -m "$model_path" \
  -f "$wav_file" \
  -l "$language" \
  -otxt \
  -of "$output_prefix" \
  >"$output_log" 2>&1; then
  echo "Transcription failed. Log follows:" >&2
  cat "$output_log" >&2
  exit 1
fi

if [[ ! -f "$output_txt" ]]; then
  echo "Expected transcript was not created: $output_txt" >&2
  exit 1
fi

cat "$output_txt"
