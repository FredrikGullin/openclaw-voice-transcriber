# OpenClaw Voice Transcriber

Local speech-to-text helper for OpenClaw voice messages.

## Purpose

OpenClaw Voice Transcriber is a privacy-first local transcription helper for voice messages, starting with Telegram `.ogg` audio files received by an OpenClaw gateway.

The first goal is deliberately small:

1. Take a local inbound voice file.
2. Convert it with `ffmpeg` when needed.
3. Transcribe it locally.
4. Return plain text for OpenClaw to use.
5. Clean up temporary audio files safely.

No external speech-to-text APIs are used by default.

## Design Principles

- Local first: audio stays on the user's machine.
- Reversible setup: keep the initial implementation easy to remove.
- Small first: start with a lightweight multilingual model before testing heavier models.
- Safe cleanup: delete temporary converted audio after transcription.
- Explicit retention: do not silently keep large media files forever.
- Gateway friendly: keep the first version as a standalone helper before deeper OpenClaw integration.

## Initial Implementation Plan

Phase 1 is a proof of concept using `whisper.cpp` and a small multilingual Whisper model.

Planned pipeline:

```text
Telegram .ogg -> ffmpeg -> local Whisper transcription -> text output -> cleanup
```

The first test target is a locally saved OpenClaw inbound media file.

If system CMake is unavailable, setup bootstraps a local CMake binary under `.local/` instead of requiring a system-wide install.

## Quick Start

Install/build the local runtime and download the default small multilingual model:

```bash
make setup
```

Transcribe one local audio file:

```bash
make transcribe INPUT=/path/to/voice-message.ogg
```

Run lightweight project validation:

```bash
make smoke
```

Run deterministic CLI contract tests without a real model or real audio:

```bash
make test
```

Clean old temporary runtime files:

```bash
make cleanup
```

## Configuration

The default setup is local and API-free.

Useful environment variables:

```bash
# Model downloaded by setup.
OCVT_MODEL_NAME=small

# Model path used by transcribe-file.sh.
OCVT_MODEL_PATH=./.local/models/ggml-small.bin

# Language passed to whisper.cpp. Use auto for Swedish/English switching.
OCVT_LANGUAGE=auto

# Keep temporary transcript/log files after transcription for debugging.
OCVT_KEEP_ARTIFACTS=false

# Optional test/debug overrides.
OCVT_FFMPEG=ffmpeg
OCVT_WHISPER_CLI=./.local/whisper.cpp/build/bin/whisper-cli
```

## CLI Contract

`scripts/transcribe-file.sh` is designed for gateway wrapping:

- stdout contains only transcript text on success,
- stderr contains a short human-readable error on failure,
- temporary `.wav`, `.txt`, and `.log` files are removed by default,
- `OCVT_KEEP_ARTIFACTS=true` keeps transcript/log artifacts for debugging.

Exit codes:

```text
0   success
2   usage error
3   input file not found
4   input file is empty
5   ffmpeg not found
6   model file not found
7   whisper.cpp binary not found
8   ffmpeg could not decode/convert input, often corrupt or unsupported audio
9   whisper.cpp transcription failed
10  expected transcript file was not created
```

## Model Strategy

Start lightweight, then benchmark:

- First test: small multilingual Whisper model.
- If quality is too low: test medium.
- If bilingual Swedish/English quality needs improvement: test a quantized `large-v3-turbo` model.
- If Swedish-only accuracy becomes important: evaluate KB-Whisper as a specialist fallback.

## Privacy

This project is intended to run locally.

The default design does not:

- upload audio to external APIs,
- store API keys,
- send transcripts to third parties,
- keep temporary `.wav` files after transcription,
- keep temporary transcript/log artifacts unless `OCVT_KEEP_ARTIFACTS=true`.

## Status

CLI MVP implemented:

- local `whisper.cpp` setup script,
- local CMake bootstrap when system CMake is missing,
- small multilingual model support,
- single-file transcription command,
- default cleanup of temporary audio/transcript/log artifacts,
- deterministic CLI contract tests for failure handling,
- initial benchmark documented in [docs/benchmarks.md](docs/benchmarks.md).

Gateway integration is intentionally not implemented yet.

## License

MIT License. See [LICENSE](LICENSE).
