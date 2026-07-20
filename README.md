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

## Model Strategy

Start lightweight, then benchmark:

- First test: small multilingual Whisper model.
- If quality is too low: test medium.
- If bilingual Swedish/English quality needs improvement: test a quantized `large-v3-turbo` model.
- If Swedish-only accuracy becomes important: evaluate KB-Whisper as a specialist fallback.

## Privacy

This project is intended to run locally.

The default design should not:

- upload audio to external APIs,
- store API keys,
- send transcripts to third parties,
- keep temporary `.wav` files after transcription.

## Status

Planning/scaffold stage. No transcription engine has been installed yet.

## License

MIT License. See [LICENSE](LICENSE).
