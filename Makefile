SHELL := /usr/bin/env bash

.PHONY: help setup transcribe smoke test cleanup

help:
	@printf '%s\n' \
		'OpenClaw Voice Transcriber' \
		'' \
		'Targets:' \
		'  make setup      Install/build local whisper.cpp helper and model' \
		'  make transcribe  Transcribe INPUT=/path/to/audio.ogg' \
		'  make smoke      Run lightweight validation checks' \
		'  make test       Run CLI contract tests' \
		'  make cleanup    Remove temporary runtime files'

setup:
	./scripts/setup-whisper-cpp.sh

transcribe:
	@test -n "$(INPUT)" || (echo 'Usage: make transcribe INPUT=/path/to/audio.ogg' >&2; exit 2)
	./scripts/transcribe-file.sh "$(INPUT)"

smoke:
	./tests/smoke.sh

test:
	./tests/cli.sh

cleanup:
	./scripts/cleanup-media.sh
