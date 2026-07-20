#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$root_dir/scripts/transcribe-file.sh"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

pass_count=0

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

make_toolchain() {
  local name="$1"
  local bin_dir="$tmp_root/$name/bin"
  local model_dir="$tmp_root/$name/models"

  mkdir -p "$bin_dir" "$model_dir"
  printf 'fake model\n' >"$model_dir/model.bin"

  cat >"$bin_dir/ffmpeg" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${OCVT_FAKE_FFMPEG_FAIL:-false}" == "true" ]]; then
  echo "invalid audio data" >&2
  exit 1
fi

out="${@: -1}"
printf 'fake wav\n' >"$out"
EOF

  cat >"$bin_dir/whisper-cli" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${OCVT_FAKE_WHISPER_FAIL:-false}" == "true" ]]; then
  echo "whisper failed" >&2
  exit 1
fi

output_prefix=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -of)
      output_prefix="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [[ "${OCVT_FAKE_SKIP_TRANSCRIPT:-false}" != "true" ]]; then
  printf 'hej från test\n' >"${output_prefix}.txt"
fi
EOF

  chmod +x "$bin_dir/ffmpeg" "$bin_dir/whisper-cli"
  printf '%s\n' "$bin_dir"
}

run_case() {
  local name="$1"
  local expected_status="$2"
  local expected_stderr="$3"
  shift 3

  local case_dir="$tmp_root/$name"
  mkdir -p "$case_dir/tmp"

  set +e
  (
    export OCVT_TMP_DIR="$case_dir/tmp"
    "$@"
  ) >"$case_dir/stdout" 2>"$case_dir/stderr"
  local status=$?
  set -e

  [[ "$status" == "$expected_status" ]] || {
    echo "STDOUT:" >&2
    cat "$case_dir/stdout" >&2 || true
    echo "STDERR:" >&2
    cat "$case_dir/stderr" >&2 || true
    fail "$name: expected exit $expected_status, got $status"
  }

  if [[ -n "$expected_stderr" ]]; then
    grep -Fq "$expected_stderr" "$case_dir/stderr" || {
      echo "STDERR:" >&2
      cat "$case_dir/stderr" >&2 || true
      fail "$name: missing stderr text: $expected_stderr"
    }
  fi

  if find "$case_dir/tmp" -type f | grep -q .; then
    find "$case_dir/tmp" -type f >&2
    fail "$name: temporary files were left behind"
  fi

  pass_count=$((pass_count + 1))
}

tool_bin="$(make_toolchain default)"
model="$tmp_root/default/models/model.bin"
input="$tmp_root/input.ogg"
printf 'not really audio\n' >"$input"
empty_input="$tmp_root/empty.ogg"
: >"$empty_input"

run_case "usage" 2 "Usage:" "$script"
run_case "missing-input" 3 "Input file not found:" "$script" "$tmp_root/missing.ogg"
run_case "empty-input" 4 "Input file is empty:" "$script" "$empty_input"
run_case "missing-ffmpeg" 5 "ffmpeg not found." env OCVT_FFMPEG="$tmp_root/no-ffmpeg" OCVT_WHISPER_CLI="$tool_bin/whisper-cli" OCVT_MODEL_PATH="$model" "$script" "$input"
run_case "missing-whisper" 7 "whisper.cpp binary not found." env OCVT_FFMPEG="$tool_bin/ffmpeg" OCVT_WHISPER_CLI="$tmp_root/no-whisper" OCVT_MODEL_PATH="$model" "$script" "$input"
run_case "missing-model" 6 "Model file not found:" env OCVT_FFMPEG="$tool_bin/ffmpeg" OCVT_WHISPER_CLI="$tool_bin/whisper-cli" OCVT_MODEL_PATH="$tmp_root/no-model.bin" "$script" "$input"
run_case "corrupt-audio" 8 "Could not decode or convert audio file." env OCVT_FAKE_FFMPEG_FAIL=true OCVT_FFMPEG="$tool_bin/ffmpeg" OCVT_WHISPER_CLI="$tool_bin/whisper-cli" OCVT_MODEL_PATH="$model" "$script" "$input"

if command -v ffmpeg >/dev/null 2>&1; then
  corrupt_input="$tmp_root/corrupt.ogg"
  printf 'this is not a valid ogg file\n' >"$corrupt_input"
  run_case "real-corrupt-audio" 8 "Could not decode or convert audio file." env OCVT_FFMPEG=ffmpeg OCVT_WHISPER_CLI="$tool_bin/whisper-cli" OCVT_MODEL_PATH="$model" "$script" "$corrupt_input"
fi

run_case "whisper-failure" 9 "Transcription failed." env OCVT_FAKE_WHISPER_FAIL=true OCVT_FFMPEG="$tool_bin/ffmpeg" OCVT_WHISPER_CLI="$tool_bin/whisper-cli" OCVT_MODEL_PATH="$model" "$script" "$input"
run_case "missing-transcript" 10 "Expected transcript was not created:" env OCVT_FAKE_SKIP_TRANSCRIPT=true OCVT_FFMPEG="$tool_bin/ffmpeg" OCVT_WHISPER_CLI="$tool_bin/whisper-cli" OCVT_MODEL_PATH="$model" "$script" "$input"

success_dir="$tmp_root/success"
mkdir -p "$success_dir/tmp"
output="$(
  OCVT_TMP_DIR="$success_dir/tmp" \
  OCVT_FFMPEG="$tool_bin/ffmpeg" \
  OCVT_WHISPER_CLI="$tool_bin/whisper-cli" \
  OCVT_MODEL_PATH="$model" \
  "$script" "$input"
)"

[[ "$output" == "hej från test" ]] || fail "success: unexpected stdout: $output"

if find "$success_dir/tmp" -type f | grep -q .; then
  find "$success_dir/tmp" -type f >&2
  fail "success: temporary files were left behind"
fi

pass_count=$((pass_count + 1))

echo "CLI checks passed ($pass_count cases)."
