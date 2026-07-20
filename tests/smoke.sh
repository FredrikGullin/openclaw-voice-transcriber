#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

required_files=(
  "README.md"
  "LICENSE"
  ".gitignore"
  ".env.example"
  "Makefile"
  "docs/architecture.md"
  "docs/benchmarks.md"
  "docs/retention.md"
  "scripts/setup-whisper-cpp.sh"
  "scripts/transcribe-file.sh"
  "scripts/transcribe-for-gateway.sh"
  "scripts/cleanup-media.sh"
  "tests/cli.sh"
  "tests/gateway.sh"
)

for file in "${required_files[@]}"; do
  test -f "$root_dir/$file" || {
    echo "Missing required file: $file" >&2
    exit 1
  }
done

bash -n "$root_dir/scripts/setup-whisper-cpp.sh"
bash -n "$root_dir/scripts/transcribe-file.sh"
bash -n "$root_dir/scripts/transcribe-for-gateway.sh"
bash -n "$root_dir/scripts/cleanup-media.sh"
bash -n "$root_dir/tests/cli.sh"
bash -n "$root_dir/tests/gateway.sh"

echo "Smoke checks passed."
