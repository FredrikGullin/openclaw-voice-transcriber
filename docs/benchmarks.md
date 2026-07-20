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

## Small vs Medium CPU Comparison

Environment:

- Runtime: `whisper.cpp`
- Hardware: CPU-only execution
- Input: Swedish Telegram `.ogg` voice message
- Audio length: 4.54 seconds
- Runs per model: 3

Expected text:

```text
Fungerar det att jag spelar in röstmeddelanden till dig, förstår du vad jag säger då?
```

Results:

```text
model        size   elapsed avg   elapsed runs        max RSS avg   transcript
small        466M   6.58 s        6.43/6.57/6.75 s    768248 KB     Ungerar det att jag spelar in röstmeddelanden till dig, förstår du vad jag säger då?
medium       1.5G   21.73 s       20.72/22.02/22.44 s 2120364 KB    "Ungerar det om jag spelar in röstmeddelanden till dig? Förstår du vad jag säger då?"
```

Resource delta:

```text
medium vs small:
elapsed time: 3.30x slower
max RSS:      2.76x higher
model size:   3.30x larger
```

Quality note:

`medium` added punctuation, but did not fix the most visible Swedish error: both models dropped the initial `F` in `Fungerar`. It also changed `att` to `om`, making the sentence slightly less faithful than `small` for this sample.

Recommendation:

Keep `small` as the default model for the first gateway wrapper. The measured quality gain from `medium` does not justify the extra CPU time, RAM, and disk footprint for short Telegram voice messages. Revisit model choice only if more real Swedish samples show recurring quality problems.
