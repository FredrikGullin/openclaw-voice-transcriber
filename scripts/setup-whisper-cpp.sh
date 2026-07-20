#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
local_dir="$root_dir/.local"
whisper_dir="$local_dir/whisper.cpp"
models_dir="$local_dir/models"
model_name="${OCVT_MODEL_NAME:-small}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Required command not found: $1" >&2
    exit 1
  }
}

require_cmd git
require_cmd make
require_cmd gcc
require_cmd g++
require_cmd curl
require_cmd ffmpeg

mkdir -p "$local_dir" "$models_dir"

if [[ ! -d "$whisper_dir/.git" ]]; then
  git clone --depth 1 https://github.com/ggml-org/whisper.cpp.git "$whisper_dir"
else
  git -C "$whisper_dir" pull --ff-only
fi

make -C "$whisper_dir" -j"$(nproc)"

if [[ -x "$whisper_dir/models/download-ggml-model.sh" ]]; then
  (cd "$whisper_dir" && ./models/download-ggml-model.sh "$model_name")
  model_file="$whisper_dir/models/ggml-$model_name.bin"
  if [[ -f "$model_file" && ! -e "$models_dir/ggml-$model_name.bin" ]]; then
    ln -s "$model_file" "$models_dir/ggml-$model_name.bin"
  fi
else
  echo "whisper.cpp model downloader not found." >&2
  exit 1
fi

echo "Setup complete."
echo "Model: $models_dir/ggml-$model_name.bin"
