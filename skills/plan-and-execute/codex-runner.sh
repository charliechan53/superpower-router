#!/usr/bin/env bash
# codex-runner.sh — Run a prompt through Codex CLI with error handling and fallback signaling.
#
# Usage: codex-runner.sh <prompt> [sandbox-mode] [working-dir]
#   prompt       — The task prompt for Codex (required)
#   sandbox-mode — read-only | workspace-write (default: read-only)
#   working-dir  — Directory to run in (default: current directory)
#
# Environment variables:
#   CODEX_MODEL   — Model to use (default: gpt-5.3-codex)
#   CODEX_EFFORT  — Reasoning effort: xhigh|high|medium|low (default: xhigh)
#   CODEX_TIMEOUT — Timeout in seconds (default: 120)
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

PROMPT="${1:?Usage: codex-runner.sh <prompt> [sandbox-mode] [working-dir]}"
SANDBOX="${2:-read-only}"
WORKDIR="${3:-$(pwd)}"

# Validate sandbox mode against allowlist
case "$SANDBOX" in
    read-only|workspace-write) ;;
    *) echo "ERROR: Invalid sandbox mode '$SANDBOX'. Allowed: read-only, workspace-write" >&2; exit 1 ;;
esac

MODEL="${CODEX_MODEL:-gpt-5.3-codex}"
EFFORT="${CODEX_EFFORT:-xhigh}"
TIMEOUT="${CODEX_TIMEOUT:-120}"
MAX_RETRIES=1

# Validate reasoning effort against allowlist
case "$EFFORT" in
    xhigh|high|medium|low) ;;
    *) echo "ERROR: Invalid CODEX_EFFORT '$EFFORT'. Allowed: xhigh, high, medium, low" >&2; exit 1 ;;
esac

# Validate working directory exists
if [[ ! -d "$WORKDIR" ]]; then
    echo "ERROR: Working directory does not exist: $WORKDIR" >&2
    exit 1
fi

# Check if codex is installed
if ! command -v codex &>/dev/null; then
    echo "ERROR: codex CLI not found. Install with: npm install -g @openai/codex" >&2
    exit 13
fi

run_codex() {
    _timeout "${TIMEOUT}" codex exec \
        -m "$MODEL" \
        --config "model_reasoning_effort=\"${EFFORT}\"" \
        --sandbox "$SANDBOX" \
        --full-auto \
        --skip-git-repo-check \
        -C "$WORKDIR" \
        "$PROMPT"
}

attempt=0
while (( attempt <= MAX_RETRIES )); do
    set +e
    output=$(run_codex 2>&1)
    exit_code=$?
    set -e

    if (( exit_code == 0 )); then
        echo "$output"
        exit 0
    fi

    # Check for rate limit
    if echo "$output" | grep -qi "429\|rate.limit\|too many requests"; then
        if (( attempt < MAX_RETRIES )); then
            echo "RETRY: Codex rate limited, waiting 30s..." >&2
            sleep 30
            ((attempt++))
            continue
        fi
        echo "ERROR: Codex rate limited after $((attempt + 1)) attempts." >&2
        echo "${output:0:500}" >&2
        exit 10
    fi

    # Check for auth failure
    if echo "$output" | grep -qi "auth\|unauthorized\|403\|login\|credential"; then
        echo "ERROR: Codex authentication failure. Run 'codex login' to fix." >&2
        echo "${output:0:500}" >&2
        exit 11
    fi

    # Check for timeout
    if (( exit_code == 124 )); then
        echo "ERROR: Codex timed out after ${TIMEOUT}s." >&2
        exit 12
    fi

    # Other failure
    if (( attempt < MAX_RETRIES )); then
        ((attempt++))
        continue
    fi

    echo "ERROR: Codex failed (exit code: $exit_code)." >&2
    echo "${output:0:500}" >&2
    exit 1
done
