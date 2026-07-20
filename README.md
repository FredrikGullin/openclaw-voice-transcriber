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

Run the gateway-friendly wrapper:

```bash
./scripts/transcribe-for-gateway.sh /path/to/voice-message.ogg
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

Clean old original inbound media after the live-test retention window:

```bash
OCVT_ORIGINAL_MAX_AGE_MINUTES=60 OCVT_TRASH_MAX_AGE_MINUTES=1440 ./scripts/cleanup-original-media.sh /home/chillazz/.openclaw/media/inbound
```

Install and start the user-level cleanup timer:

```bash
mkdir -p ~/.config/systemd/user
cp systemd/user/openclaw-voice-transcriber-cleanup.* ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now openclaw-voice-transcriber-cleanup.timer
```

## Configuration

The default setup is local and API-free.

Useful environment variables:

```bash
# Model downloaded by setup.
OCVT_MODEL_NAME=small

# Model path used by transcribe-file.sh.
OCVT_MODEL_PATH=./.local/models/ggml-small.bin

# Language passed to whisper.cpp by the core CLI. Use auto for Swedish/English switching.
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

## Gateway Wrapper

`scripts/transcribe-for-gateway.sh` is a thin wrapper around the CLI for later OpenClaw integration.

Its contract is:

- stdout always contains text that is safe to send back to the user,
- exit `0` means stdout is the transcript,
- non-zero exit means stdout is a short user-facing failure message,
- stderr contains the technical transcription error for logs/debugging,
- the default model is `./.local/models/ggml-small.bin`,
- the default gateway language hint is Swedish (`sv`) to avoid short Swedish voice notes being misdetected as English,
- set `OCVT_LANGUAGE=auto` when testing mixed Swedish/English input,
- it does not delete original inbound audio.

This wrapper does not connect to Telegram by itself. The OpenClaw gateway can call it later when a local inbound voice file is available.

## Original Media Retention

Original inbound audio should be kept for the shortest practical time.

Initial live-test default:

- keep original voice files for up to 60 minutes,
- delete temporary converted audio/transcript/log artifacts immediately,
- do not add a separate LLM normalization layer before the first live test,
- revisit retention once a handful of real voice messages have been tested.

`scripts/cleanup-original-media.sh` cleans old original audio files from a chosen directory. It prefers recoverable trash deletion and requires `OCVT_ALLOW_RM_DELETE=true` before using hard `rm` deletion.

The same cleanup run also purges only this transcriber's own trashed original media after `OCVT_TRASH_MAX_AGE_MINUTES` so recoverable trash does not accumulate forever. It does not empty the whole user trash.

The optional systemd user timer in `systemd/user/` runs this cleanup every 15 minutes with a 60-minute original-media retention window and a 24-hour transcriber-trash purge window.

## Voice Reply Policy

For Fredo's normal Telegram workflow, the agent should answer voice messages naturally after transcription.

- Do not print the raw transcript by default.
- Print the transcript only when Fredo asks for it, or when debugging transcription quality.
- If the meaning is clear enough, roughly 90% confidence or better, answer naturally without a transcription disclaimer.
- If the meaning is genuinely uncertain, say `jag tolkar det som...` before acting.
- For low-confidence cases, offer to print the raw transcript if that would help verify what was heard.
- Use the interpreted meaning for normal work, todos, project status, and memory.
- Keep raw transcript text as temporary diagnostic context, not as long-term truth.

This policy depends on the agent/LLM layer that consumes the transcript. The transcriber itself only produces raw text. Behavior may differ when OpenClaw runs a different model family, such as Anthropic models or a local LLM, especially for Swedish/English mixed technical speech and confidence judgment. Re-test the reply policy when changing the OpenClaw model.

## Model Strategy

Start lightweight, then benchmark only when quality requires it:

- Default for first gateway wrapper: small multilingual Whisper model.
- Tested alternative: medium.
- If bilingual Swedish/English quality needs improvement: test a quantized `large-v3-turbo` model.
- If Swedish-only accuracy becomes important: evaluate KB-Whisper as a specialist fallback.

Current benchmark result: `medium` was about 3.3x slower and 2.8x higher RAM than `small` on the first Swedish Telegram sample, without fixing the visible first-word error. Keep `small` as default unless more real samples show recurring quality problems.

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
- gateway-friendly wrapper with user-facing failure messages,
- original-media retention cleanup helper,
- default cleanup of temporary audio/transcript/log artifacts,
- deterministic CLI contract tests for failure handling,
- initial benchmark documented in [docs/benchmarks.md](docs/benchmarks.md).

Gateway wrapper integration has been wired through OpenClaw `tools.media.audio` in Fredo's local runtime config. The repository remains a standalone helper and does not modify OpenClaw's installed runtime code.

## License

MIT License. See [LICENSE](LICENSE).
