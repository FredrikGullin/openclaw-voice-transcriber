# Benchmarks

Benchmarks are local observations, not universal performance claims.

## Initial CPU Test

Environment:

- Model: `ggml-small.bin`
- Runtime: `whisper.cpp`
- Hardware: CPU-only execution
- Input: short Swedish Telegram `.ogg` voice message
- Audio length: approximately 4.5 seconds

Result:

```text
elapsed: 0:06.42
max RSS: 768368 KB
language detected: sv
```

Quality note:

The initial transcription was understandable and nearly correct, but the first word lost one initial character. This is acceptable for the first lightweight MVP, but larger models should be benchmarked before gateway integration is considered complete.
