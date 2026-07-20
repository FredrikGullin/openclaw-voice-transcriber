#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/audio.ogg" >&2
  exit 2
fi

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
input_file="$1"
tmp_dir="${OCVT_TMP_DIR:-$root_dir/.local/tmp}"
model_path="${OCVT_MODEL_PATH:-$root_dir/.local/models/ggml-small.bin}"
language="${OCVT_LANGUAGE:-sv}"

mkdir -p "$tmp_dir"

stdout_file="$(mktemp "$tmp_dir/gateway-transcript.XXXXXX")"
stderr_file="$(mktemp "$tmp_dir/gateway-error.XXXXXX")"

cleanup() {
  rm -f "$stdout_file" "$stderr_file"
}
trap cleanup EXIT

set +e
OCVT_MODEL_PATH="$model_path" OCVT_LANGUAGE="$language" "$root_dir/scripts/transcribe-file.sh" "$input_file" >"$stdout_file" 2>"$stderr_file"
status=$?
set -e

if [[ "$status" -eq 0 ]]; then
  cat "$stdout_file"
  exit 0
fi

technical_error="$(tr '\n' ' ' <"$stderr_file" | sed 's/[[:space:]]*$//')"
if [[ -n "$technical_error" ]]; then
  echo "Technical transcription error (exit $status): $technical_error" >&2
else
  echo "Technical transcription error (exit $status): unknown error" >&2
fi

case "$status" in
  3)
    echo "Jag kunde inte hitta ljudfilen som skulle transkriberas."
    ;;
  4)
    echo "Jag kunde inte transkribera ljudfilen eftersom den är tom."
    ;;
  5)
    echo "Transkribering är inte tillgänglig just nu eftersom ljudkonverteraren saknas."
    ;;
  6)
    echo "Transkribering är inte tillgänglig just nu eftersom språkmodellen saknas."
    ;;
  7)
    echo "Transkribering är inte tillgänglig just nu eftersom transkriberingsmotorn saknas."
    ;;
  8)
    echo "Jag kunde inte transkribera ljudfilen eftersom den verkar vara skadad eller i ett format jag inte kan läsa."
    ;;
  9)
    echo "Jag kunde inte transkribera ljudfilen eftersom transkriberingsmotorn misslyckades."
    ;;
  10)
    echo "Jag kunde inte transkribera ljudfilen eftersom ingen text skapades."
    ;;
  *)
    echo "Jag kunde inte transkribera ljudfilen just nu."
    ;;
esac

exit "$status"
