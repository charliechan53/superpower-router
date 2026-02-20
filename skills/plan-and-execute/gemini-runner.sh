#!/usr/bin/env bash
# gemini-runner.sh — Run a prompt through Gemini CLI with error handling and fallback signaling.
#
# Usage: gemini-runner.sh <prompt> [model]
#   prompt — The task prompt for Gemini (required)
#   model  — Gemini model to use (default: CLI default)
#
# Environment variables:
#   GEMINI_TIMEOUT — Timeout in seconds (default: 60)
#
# Exit codes:
#   0   — Success
#   10  — Rate limited (fallback recommended)
#   11  — Auth failure (report to user)
#   12  — Timeout (fallback recommended)
#   13  — CLI not found (report to user)
#   1   — Other failure (fallback recommended)

set -euo pipefail

# macOS doesn't ship 'timeout'; use gtimeout (coreutils) or run without timeout
_timeout() {
    local secs="$1"; shift
    if command -v timeout &>/dev/null; then
        timeout "$secs" "$@"
    elif command -v gtimeout &>/dev/null; then
        gtimeout "$secs" "$@"
    else
        "$@"
    fi
}

PROMPT="${1:?Usage: gemini-runner.sh <prompt> [model]}"
MODEL="${2:-}"

TIMEOUT="${GEMINI_TIMEOUT:-60}"
MAX_RETRIES=1

# Check if gemini is installed
if ! command -v gemini &>/dev/null; then
    echo "ERROR: gemini CLI not found. Install from: https://github.com/google-gemini/gemini-cli" >&2
    exit 13
fi

MODEL_ARGS=()
if [[ -n "$MODEL" ]]; then
    MODEL_ARGS=(-m "$MODEL")
fi

run_gemini() {
    _timeout "${TIMEOUT}" gemini "${MODEL_ARGS[@]+"${MODEL_ARGS[@]}"}" "$PROMPT" --output-format text 2>&1
}

attempt=0
while (( attempt <= MAX_RETRIES )); do
    set +e
    output=$(run_gemini 2>&1)
    exit_code=$?
    set -e

    if (( exit_code == 0 )); then
        echo "$output"
        exit 0
    fi

    # Check for rate limit
    if echo "$output" | grep -qi "429\|RESOURCE_EXHAUSTED\|rateLimitExceeded\|rate.limit\|capacity"; then
        if (( attempt < MAX_RETRIES )); then
            echo "RETRY: Gemini rate limited, waiting 30s..." >&2
            sleep 30
            ((attempt++))
            continue
        fi
        echo "ERROR: Gemini rate limited after $((attempt + 1)) attempts." >&2
        echo "${output:0:500}" >&2
        exit 10
    fi

    # Check for auth failure
    if echo "$output" | grep -qi "auth\|unauthorized\|403\|credential\|UNAUTHENTICATED"; then
        echo "ERROR: Gemini authentication failure. Run 'gemini' interactively to authenticate." >&2
        echo "${output:0:500}" >&2
        exit 11
    fi

    # Check for timeout
    if (( exit_code == 124 )); then
        echo "ERROR: Gemini timed out after ${TIMEOUT}s." >&2
        exit 12
    fi

    # Other failure
    if (( attempt < MAX_RETRIES )); then
        ((attempt++))
        continue
    fi

    echo "ERROR: Gemini failed (exit code: $exit_code)." >&2
    echo "${output:0:500}" >&2
    exit 1
done
