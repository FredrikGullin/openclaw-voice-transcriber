# Audio Retention Policy

This project is designed to avoid long-term audio storage by default.

## Recommended Policy

- Temporary converted `.wav` files are deleted after each transcription attempt.
- Temporary transcript/log artifacts are deleted by default after the transcript is printed.
- Original inbound `.ogg` files should be kept for the shortest practical time.
- During the first live test window, keep original inbound audio for up to 60 minutes so obvious transcription/debug issues can be investigated.
- After integration is proven, successful original audio should be deleted immediately after transcript handling is accepted.
- Failed transcriptions may keep the original input for a short troubleshooting window; start with 60 minutes and extend only if debugging actually needs it.
- Media moved to recoverable trash should be permanently purged later, but only for this transcriber's own files.

## Suggested Defaults After Gateway Integration

```text
temporary WAV: delete immediately
temporary transcript/log: delete immediately unless debugging is enabled
successful original audio during first live test: keep up to 60 minutes
successful original audio after stabilization: delete after transcript is accepted
failed original audio: keep up to 60 minutes unless actively debugging
transcriber trash entries: purge after 24 hours
transcript text: keep in normal OpenClaw conversation history
```

Use `scripts/cleanup-original-media.sh` for local original-media cleanup:

```bash
OCVT_ORIGINAL_MAX_AGE_MINUTES=60 OCVT_TRASH_MAX_AGE_MINUTES=1440 ./scripts/cleanup-original-media.sh /home/chillazz/.openclaw/media/inbound
```

The helper prefers `trash-put` or `gio trash`. It only uses hard `rm` deletion when `OCVT_ALLOW_RM_DELETE=true` is explicitly set.

After moving old original media to trash, the helper also scans the Freedesktop trash metadata and permanently removes trashed media whose original path was inside the configured inbound media directory and whose deletion time is older than `OCVT_TRASH_MAX_AGE_MINUTES`. It does not run `gio trash --empty`, because that would clear unrelated user trash.

## LLM Normalization

The first live test should not add a separate LLM normalization layer.

Current flow:

```text
original audio -> local whisper.cpp transcript -> OpenClaw/LLM conversation
```

The LLM can usually infer obvious minor transcript mistakes once the text is in the conversation, but the transcriber should keep returning the raw local transcript for now. Add explicit `raw_transcript` + `normalized_transcript` later only if real voice samples show that transcript mistakes frequently disrupt commands.

## Voice Reply Output

Default user-facing behavior:

- Answer voice messages naturally.
- Do not print the raw transcript unless requested.
- When the meaning is clear enough, roughly 90% confidence or better, do not add a transcription disclaimer.
- When genuinely uncertain, say `jag tolkar det som...` and then state the interpreted meaning before acting.
- In low-confidence cases, offer to print the raw transcription result so the user can decide whether it is useful.
- Review this policy after roughly 10-20 real voice messages and decide whether a light glossary/normalization layer is worth adding.

## Rationale

Voice messages can contain private context. Keeping audio indefinitely increases privacy risk without much benefit once text has been extracted.
