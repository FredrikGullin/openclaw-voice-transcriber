#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$root_dir/scripts/transcribe-for-gateway.sh"

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

pass_count=0

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

make_toolchain() {
  local bin_dir="$tmp_root/bin"
  local model_dir="$tmp_root/models"

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

printf 'hej från gateway\n' >"${output_prefix}.txt"
EOF

  chmod +x "$bin_dir/ffmpeg" "$bin_dir/whisper-cli"
}

run_gateway_case() {
  local name="$1"
  local expected_status="$2"
  local expected_stdout="$3"
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

  grep -Fq "$expected_stdout" "$case_dir/stdout" || {
    echo "STDOUT:" >&2
    cat "$case_dir/stdout" >&2 || true
    fail "$name: missing stdout text: $expected_stdout"
  }

  if [[ "$expected_status" != "0" ]]; then
    grep -Fq "Technical transcription error (exit $expected_status):" "$case_dir/stderr" || {
      echo "STDERR:" >&2
      cat "$case_dir/stderr" >&2 || true
      fail "$name: missing technical stderr"
    }
  fi

  if find "$case_dir/tmp" -type f | grep -q .; then
    find "$case_dir/tmp" -type f >&2
    fail "$name: temporary files were left behind"
  fi

  pass_count=$((pass_count + 1))
}

make_toolchain

input="$tmp_root/input.ogg"
model="$tmp_root/models/model.bin"
printf 'not really audio\n' >"$input"

run_gateway_case "success" 0 "hej från gateway" env OCVT_FFMPEG="$tmp_root/bin/ffmpeg" OCVT_WHISPER_CLI="$tmp_root/bin/whisper-cli" OCVT_MODEL_PATH="$model" "$script" "$input"
run_gateway_case "missing-input" 3 "Jag kunde inte hitta ljudfilen som skulle transkriberas." env OCVT_FFMPEG="$tmp_root/bin/ffmpeg" OCVT_WHISPER_CLI="$tmp_root/bin/whisper-cli" OCVT_MODEL_PATH="$model" "$script" "$tmp_root/missing.ogg"
run_gateway_case "missing-model" 6 "Transkribering är inte tillgänglig just nu eftersom språkmodellen saknas." env OCVT_FFMPEG="$tmp_root/bin/ffmpeg" OCVT_WHISPER_CLI="$tmp_root/bin/whisper-cli" OCVT_MODEL_PATH="$tmp_root/missing-model.bin" "$script" "$input"
run_gateway_case "corrupt-audio" 8 "Jag kunde inte transkribera ljudfilen eftersom den verkar vara skadad eller i ett format jag inte kan läsa." env OCVT_FAKE_FFMPEG_FAIL=true OCVT_FFMPEG="$tmp_root/bin/ffmpeg" OCVT_WHISPER_CLI="$tmp_root/bin/whisper-cli" OCVT_MODEL_PATH="$model" "$script" "$input"

echo "Gateway wrapper checks passed ($pass_count cases)."
