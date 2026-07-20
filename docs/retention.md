# Audio Retention Policy

This project is designed to avoid long-term audio storage by default.

## Recommended Policy

- Temporary converted `.wav` files are deleted after each transcription attempt.
- Temporary transcript/log artifacts are deleted by default after the transcript is printed.
- Original inbound `.ogg` files are not deleted by the MVP until the user explicitly approves automatic cleanup.
- After integration is proven, original audio should be deleted after successful transcription.
- Failed transcriptions may keep the original input for a short troubleshooting window.

## Suggested Defaults After Gateway Integration

```text
temporary WAV: delete immediately
temporary transcript/log: delete immediately unless debugging is enabled
successful original audio: delete after transcript is accepted
failed original audio: keep up to 24 hours
transcript text: keep in normal OpenClaw conversation history
```

## Rationale

Voice messages can contain private context. Keeping audio indefinitely increases privacy risk without much benefit once text has been extracted.
