#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 /path/to/audio.ogg" >&2
}

die() {
  local status="$1"
  shift
  echo "$*" >&2
  exit "$status"
}

if [[ $# -lt 1 ]]; then
  usage
  exit 2
fi

input_file="$1"
test -f "$input_file" || die 3 "Input file not found: $input_file"
test -s "$input_file" || die 4 "Input file is empty: $input_file"

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
local_dir="$root_dir/.local"
tmp_dir="${OCVT_TMP_DIR:-$local_dir/tmp}"
model_path="${OCVT_MODEL_PATH:-$local_dir/models/ggml-small.bin}"
language="${OCVT_LANGUAGE:-auto}"
keep_artifacts="${OCVT_KEEP_ARTIFACTS:-false}"
ffmpeg_bin="${OCVT_FFMPEG:-ffmpeg}"

mkdir -p "$tmp_dir"

find_ffmpeg() {
  if [[ "$ffmpeg_bin" == */* ]]; then
    [[ -x "$ffmpeg_bin" ]] && printf '%s\n' "$ffmpeg_bin"
    return
  fi

  command -v "$ffmpeg_bin"
}

find_whisper_cli() {
  if [[ -n "${OCVT_WHISPER_CLI:-}" ]]; then
    [[ -x "$OCVT_WHISPER_CLI" ]] && printf '%s\n' "$OCVT_WHISPER_CLI"
    return
  fi

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

resolved_ffmpeg="$(find_ffmpeg)" || die 5 "ffmpeg not found. Install ffmpeg or set OCVT_FFMPEG."

whisper_cli="$(find_whisper_cli)" || die 7 "whisper.cpp binary not found. Run: make setup or set OCVT_WHISPER_CLI."

test -f "$model_path" || die 6 "Model file not found: $model_path. Run: make setup or set OCVT_MODEL_PATH."

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

if ! "$resolved_ffmpeg" \
  -hide_banner \
  -loglevel error \
  -y \
  -i "$input_file" \
  -ar 16000 \
  -ac 1 \
  -c:a pcm_s16le \
  "$wav_file" \
  >"$output_log" 2>&1; then
  echo "Could not decode or convert audio file. It may be corrupt or unsupported: $input_file" >&2
  if [[ "$keep_artifacts" == "true" ]]; then
    echo "Debug log: $output_log" >&2
  fi
  exit 8
fi

if ! "$whisper_cli" \
  -m "$model_path" \
  -f "$wav_file" \
  -l "$language" \
  -otxt \
  -of "$output_prefix" \
  >"$output_log" 2>&1; then
  echo "Transcription failed. whisper.cpp could not produce a transcript." >&2
  if [[ "$keep_artifacts" == "true" ]]; then
    echo "Debug log: $output_log" >&2
  fi
  exit 9
fi

if [[ ! -f "$output_txt" ]]; then
  echo "Expected transcript was not created: $output_txt" >&2
  if [[ "$keep_artifacts" == "true" ]]; then
    echo "Debug log: $output_log" >&2
  fi
  exit 10
fi

cat "$output_txt"
