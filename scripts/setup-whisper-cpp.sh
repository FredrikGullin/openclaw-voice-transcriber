#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
local_dir="$root_dir/.local"
whisper_dir="$local_dir/whisper.cpp"
models_dir="$local_dir/models"
downloads_dir="$local_dir/downloads"
model_name="${OCVT_MODEL_NAME:-small}"
cmake_version="${OCVT_CMAKE_VERSION:-4.4.0}"

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
require_cmd tar
require_cmd sha256sum

mkdir -p "$local_dir" "$models_dir" "$downloads_dir"

detect_cmake_arch() {
  case "$(uname -m)" in
    x86_64 | amd64)
      echo "x86_64"
      ;;
    aarch64 | arm64)
      echo "aarch64"
      ;;
    *)
      echo "Unsupported architecture for local CMake bootstrap: $(uname -m)" >&2
      exit 1
      ;;
  esac
}

ensure_cmake() {
  if command -v cmake >/dev/null 2>&1; then
    return 0
  fi

  local arch
  arch="$(detect_cmake_arch)"

  local cmake_dir="$local_dir/cmake-$cmake_version-linux-$arch"
  local cmake_bin="$cmake_dir/bin/cmake"
  local asset="cmake-$cmake_version-linux-$arch.tar.gz"
  local asset_url="https://github.com/Kitware/CMake/releases/download/v$cmake_version/$asset"
  local sha_url="https://github.com/Kitware/CMake/releases/download/v$cmake_version/cmake-$cmake_version-SHA-256.txt"
  local asset_path="$downloads_dir/$asset"
  local sha_path="$downloads_dir/cmake-$cmake_version-SHA-256.txt"

  if [[ ! -x "$cmake_bin" ]]; then
    echo "System CMake not found. Bootstrapping local CMake $cmake_version for linux-$arch."

    if [[ ! -f "$asset_path" ]]; then
      curl --fail --location --output "$asset_path" "$asset_url"
    fi

    if [[ ! -f "$sha_path" ]]; then
      curl --fail --location --output "$sha_path" "$sha_url"
    fi

    (cd "$downloads_dir" && grep " $asset$" "$sha_path" | sha256sum --check -)
    tar -xzf "$asset_path" -C "$local_dir"
  fi

  export PATH="$cmake_dir/bin:$PATH"
}

ensure_cmake

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
