# Architecture

OpenClaw Voice Transcriber starts as a local command-line helper. Gateway integration should come only after the CLI path is proven.

## MVP Pipeline

```text
inbound Telegram .ogg
  -> ffmpeg conversion to 16 kHz mono WAV
  -> local whisper.cpp transcription
  -> plain text output
  -> temporary file cleanup
```

## Boundaries

The initial implementation does not modify the OpenClaw gateway. It provides a tested local command that can later be called by the gateway or by an OpenClaw tool wrapper.

## Local Runtime Layout

Runtime artifacts are intentionally kept out of Git:

```text
.local/
  cmake-*/           optional local CMake bootstrap when system CMake is missing
  downloads/         downloaded build/runtime archives
  whisper.cpp/       cloned upstream source/build
  models/            downloaded local model files
  tmp/               temporary converted audio
```

## Script Responsibilities

- `scripts/setup-whisper-cpp.sh`: install/build the local whisper.cpp runtime and download a small multilingual model.
- `scripts/transcribe-file.sh`: convert one input audio file and return transcription text.
- `scripts/transcribe-for-gateway.sh`: map CLI success/failure into text that is safe for a later gateway caller to send back to the user.
- `scripts/cleanup-media.sh`: remove stale local temporary files.
- `tests/smoke.sh`: validate project structure and shell syntax without requiring a model download.
- `tests/cli.sh`: validate the CLI success/failure contract with fake `ffmpeg` and `whisper-cli` binaries.
- `tests/gateway.sh`: validate the gateway wrapper's user-facing success/failure contract.

## CLI Contract

The gateway should treat `scripts/transcribe-file.sh` as a small process boundary:

- exit `0`: stdout is transcript text,
- non-zero exit: stderr is a short human-readable error,
- no stack traces or raw tool logs are printed by default,
- temporary `.wav`, `.txt`, and `.log` files are deleted by default,
- `OCVT_KEEP_ARTIFACTS=true` keeps transcript/log artifacts for debugging.

Current exit codes:

```text
2   usage error
3   input file not found
4   input file is empty
5   ffmpeg not found
6   model file not found
7   whisper.cpp binary not found
8   ffmpeg could not decode/convert input
9   whisper.cpp transcription failed
10  expected transcript file was not created
```

## Gateway Wrapper Contract

`scripts/transcribe-for-gateway.sh` is intentionally thin. It does not connect to Telegram or mutate OpenClaw gateway state.

Its current contract:

- call `scripts/transcribe-file.sh` with the default `small` model unless `OCVT_MODEL_PATH` overrides it,
- on success, print the transcript to stdout and exit `0`,
- on failure, print a short Swedish user-facing message to stdout and exit with the underlying CLI exit code,
- write the technical error to stderr for logs/debugging,
- remove wrapper temporary stdout/stderr capture files,
- never delete the original inbound audio file.

## Later Integration

Once the CLI path works, gateway integration can wrap the transcription command when an inbound Telegram voice file is available.

The gateway path should preserve these rules:

- run one transcription job at a time,
- keep timeouts around external process calls,
- remove temporary `.wav` files after each run,
- delete original voice files only after successful transcription and after retention policy is approved,
- return clear error messages when transcription fails.
