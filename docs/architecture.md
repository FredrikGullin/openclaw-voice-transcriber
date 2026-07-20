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
- `scripts/cleanup-media.sh`: remove stale local temporary files.
- `tests/smoke.sh`: validate project structure and shell syntax without requiring a model download.

## Later Integration

Once the CLI path works, gateway integration can wrap the transcription command when an inbound Telegram voice file is available.

The gateway path should preserve these rules:

- run one transcription job at a time,
- keep timeouts around external process calls,
- remove temporary `.wav` files after each run,
- delete original voice files only after successful transcription and after retention policy is approved,
- return clear error messages when transcription fails.
