#!/usr/bin/env bash
# gemini-runner.sh — Run a prompt through Gemini CLI with error handling and fallback signaling.
#
# Usage: gemini-runner.sh <prompt> [model]
#   prompt — The task prompt for Gemini (required)
#   model  — Gemini model to use (default: CLI default)
#
# Environment variables:
#   GEMINI_TIMEOUT — Timeout in seconds (default: 600)
#   GEMINI_FALLBACK_TO_CODEX_ON_FIRST_RATE_LIMIT — 1 to try Codex on first Gemini rate-limit (default: 1)
#   GEMINI_CODEX_FALLBACK_MODEL — Codex model for Gemini fallback (default: gpt-5.2-codex)
#   GEMINI_CODEX_FALLBACK_SANDBOX — Codex sandbox for fallback: read-only|workspace-write (default: read-only)
#   GEMINI_CODEX_FALLBACK_WORKDIR — Working directory for Codex fallback (default: current directory)
#
# Exit codes:
#   0   — Success
#   10  — Rate limited (fallback recommended)
#   11  — Auth failure (report to user)
#   12  — Timeout (fallback recommended)
#   13  — CLI not found (report to user)
#   1   — Other failure (fallback recommended)

set -euo pipefail

resolve_script_dir() {
    local source="${BASH_SOURCE[0]:-$0}"
    while [[ -L "$source" ]]; do
        local dir
        dir="$(cd -P "$(dirname "$source")" && pwd)"
        source="$(readlink "$source")"
        [[ "$source" != /* ]] && source="${dir}/${source}"
    done
    cd -P "$(dirname "$source")" && pwd
}

SCRIPT_DIR="$(resolve_script_dir)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
METRICS_HELPER="${PLUGIN_ROOT}/hooks/router-metrics.sh"
CODEX_RUNNER="${SCRIPT_DIR}/codex-runner.sh"
JQ_BIN="/usr/bin/jq"
if [[ ! -x "$JQ_BIN" ]]; then
    JQ_BIN="$(command -v jq || true)"
fi

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

TIMEOUT="${GEMINI_TIMEOUT:-600}"
MAX_RETRIES=1
FALLBACK_TO_CODEX_ON_FIRST_RATE_LIMIT="${GEMINI_FALLBACK_TO_CODEX_ON_FIRST_RATE_LIMIT:-1}"
CODEX_FALLBACK_MODEL="${GEMINI_CODEX_FALLBACK_MODEL:-gpt-5.2-codex}"
CODEX_FALLBACK_SANDBOX="${GEMINI_CODEX_FALLBACK_SANDBOX:-read-only}"
CODEX_FALLBACK_WORKDIR="${GEMINI_CODEX_FALLBACK_WORKDIR:-$(pwd)}"

# Check if gemini is installed
if ! command -v gemini &>/dev/null; then
    echo "ERROR: gemini CLI not found. Install from: https://github.com/google-gemini/gemini-cli" >&2
    exit 13
fi

MODEL_ARGS=()
if [[ -n "$MODEL" ]]; then
    MODEL_ARGS=(-m "$MODEL")
fi

case "$FALLBACK_TO_CODEX_ON_FIRST_RATE_LIMIT" in
    0|1) ;;
    *) echo "ERROR: Invalid GEMINI_FALLBACK_TO_CODEX_ON_FIRST_RATE_LIMIT '$FALLBACK_TO_CODEX_ON_FIRST_RATE_LIMIT'. Allowed: 0, 1" >&2; exit 1 ;;
esac

case "$CODEX_FALLBACK_SANDBOX" in
    read-only|workspace-write) ;;
    *) echo "ERROR: Invalid GEMINI_CODEX_FALLBACK_SANDBOX '$CODEX_FALLBACK_SANDBOX'. Allowed: read-only, workspace-write" >&2; exit 1 ;;
esac

run_codex_fallback() {
    if [[ ! -x "$CODEX_RUNNER" ]]; then
        echo "WARN: Codex fallback unavailable (runner not found: $CODEX_RUNNER)." >&2
        return 1
    fi

    echo "FALLBACK: Gemini rate limited on first attempt; delegating to Codex (${CODEX_FALLBACK_MODEL})." >&2
    CODEX_MODEL="$CODEX_FALLBACK_MODEL" \
      /bin/bash "$CODEX_RUNNER" "$PROMPT" "$CODEX_FALLBACK_SANDBOX" "$CODEX_FALLBACK_WORKDIR"
}

metrics_cmd() {
    if [[ ! -x "$METRICS_HELPER" ]]; then
        return 0
    fi
    /bin/bash "$METRICS_HELPER" "$@" >/dev/null 2>&1 || true
}

run_gemini() {
    _timeout "${TIMEOUT}" gemini "${MODEL_ARGS[@]+"${MODEL_ARGS[@]}"}" "$PROMPT" --output-format json 2>&1
}

extract_json_payload() {
    local output="$1"
    printf '%s\n' "$output" | awk '
        BEGIN { capture = 0 }
        /^[[:space:]]*{/ { capture = 1 }
        { if (capture) print }
    '
}

record_gemini_usage() {
    local json_payload="$1"
    if [[ ! -x "$METRICS_HELPER" || -z "$JQ_BIN" || ! -x "$JQ_BIN" ]]; then
        return 0
    fi

    local stats_tsv
    stats_tsv="$(
        printf '%s\n' "$json_payload" | "$JQ_BIN" -r -s '
            def model_stats($o):
              [
                ([ ($o.stats.models // {})[] | (.tokens.input // 0) ] | add // 0),
                ([ ($o.stats.models // {})[] | (.tokens.prompt // .tokens.input // 0) ] | add // 0),
                ([ ($o.stats.models // {})[] | (.tokens.candidates // 0) ] | add // 0),
                ([ ($o.stats.models // {})[] | (.tokens.thoughts // 0) ] | add // 0),
                ([ ($o.stats.models // {})[] | (.tokens.tool // 0) ] | add // 0),
                ([ ($o.stats.models // {})[] | (.tokens.cached // 0) ] | add // 0),
                ([ ($o.stats.models // {})[] | (.tokens.total // 0) ] | add // 0)
              ];
            def stream_stats($o):
              [
                ($o.stats.input_tokens // $o.stats.input // 0),
                ($o.stats.input_tokens // $o.stats.input // 0),
                ($o.stats.output_tokens // 0),
                0,
                ($o.stats.tool_calls // 0),
                ($o.stats.cached // 0),
                ($o.stats.total_tokens // (($o.stats.input_tokens // $o.stats.input // 0) + ($o.stats.output_tokens // 0)))
              ];
            [
              .[] as $o
              | if (($o.stats.models? // null) != null) then
                  model_stats($o)
                elif ($o.type == "result" and ($o.stats? != null)) then
                  stream_stats($o)
                elif ($o.stats? != null and (($o.stats.total_tokens? // null) != null or ($o.stats.input_tokens? // null) != null or ($o.stats.input? // null) != null)) then
                  stream_stats($o)
                else
                  empty
                end
            ] | last // empty | @tsv
        ' 2>/dev/null || true
    )"

    if [[ -z "$stats_tsv" ]]; then
        return 0
    fi

    local input_tokens prompt_tokens candidates_tokens thoughts_tokens tool_tokens cached_tokens total_tokens
    IFS=$'\t' read -r input_tokens prompt_tokens candidates_tokens thoughts_tokens tool_tokens cached_tokens total_tokens <<< "$stats_tsv"

    /bin/bash "$METRICS_HELPER" add_gemini \
        "${input_tokens:-0}" \
        "${prompt_tokens:-0}" \
        "${candidates_tokens:-0}" \
        "${thoughts_tokens:-0}" \
        "${tool_tokens:-0}" \
        "${cached_tokens:-0}" \
        "${total_tokens:-0}" >/dev/null 2>&1 || true
}

extract_retry_after_seconds() {
    local output="$1"
    local retry_after=""

    retry_after="$(printf '%s\n' "$output" | sed -nE 's/.*[Rr]etry in ([0-9]+([.][0-9]+)?)s.*/\1/p' | head -n 1)"
    if [[ -z "$retry_after" ]]; then
        retry_after="$(printf '%s\n' "$output" | sed -nE 's/.*"retryDelay"[[:space:]]*:[[:space:]]*"([0-9]+)s".*/\1/p' | head -n 1)"
    fi
    printf '%s\n' "$retry_after"
}

attempt=0
while (( attempt <= MAX_RETRIES )); do
    metrics_cmd mark_attempt gemini
    set +e
    output=$(run_gemini 2>&1)
    exit_code=$?
    set -e

    if (( exit_code == 0 )); then
        metrics_cmd mark_success gemini
        json_payload="$(extract_json_payload "$output")"
        if [[ -n "$JQ_BIN" && -x "$JQ_BIN" ]] && printf '%s\n' "$json_payload" | "$JQ_BIN" empty >/dev/null 2>&1; then
            response="$(printf '%s\n' "$json_payload" | "$JQ_BIN" -r '.response // empty' 2>/dev/null || true)"
            record_gemini_usage "$json_payload"
            if [[ -n "$response" ]]; then
                echo "$response"
            else
                echo "$output"
            fi
        else
            echo "$output"
        fi
        exit 0
    fi

    # Check for rate limit
    if echo "$output" | grep -qi "429\|RESOURCE_EXHAUSTED\|rateLimitExceeded\|rate.limit\|capacity"; then
        retry_after="$(extract_retry_after_seconds "$output")"
        metrics_cmd set_rate_limit gemini "${retry_after:-}" "rate_limited"
        metrics_cmd mark_failure gemini "$exit_code" "rate_limited"
        if (( attempt == 0 )) && [[ "$FALLBACK_TO_CODEX_ON_FIRST_RATE_LIMIT" == "1" ]]; then
            if run_codex_fallback; then
                exit 0
            fi
            echo "WARN: Codex fallback failed; continuing Gemini retry policy." >&2
        fi
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
        metrics_cmd mark_failure gemini "$exit_code" "authentication_failure"
        echo "ERROR: Gemini authentication failure. Run 'gemini' interactively to authenticate." >&2
        echo "${output:0:500}" >&2
        exit 11
    fi

    # Check for timeout
    if (( exit_code == 124 )); then
        metrics_cmd mark_failure gemini "$exit_code" "timeout"
        echo "ERROR: Gemini timed out after ${TIMEOUT}s." >&2
        exit 12
    fi

    # Other failure
    metrics_cmd mark_failure gemini "$exit_code" "general_failure"
    if (( attempt < MAX_RETRIES )); then
        ((attempt++))
        continue
    fi

    echo "ERROR: Gemini failed (exit code: $exit_code)." >&2
    echo "${output:0:500}" >&2
    exit 1
done
