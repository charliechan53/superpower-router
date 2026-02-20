#!/usr/bin/env bash
# codex-runner.sh — Run a prompt through Codex CLI with error handling and fallback signaling.
#
# Usage: codex-runner.sh <prompt> [sandbox-mode] [working-dir]
#   prompt       — The task prompt for Codex (required)
#   sandbox-mode — read-only | workspace-write (default: read-only)
#   working-dir  — Directory to run in (default: current directory)
#
# Legacy-compatible usage:
#   codex-runner.sh <prompt> <working-dir> [sandbox-mode]
#   - If only <working-dir> is provided, sandbox defaults to workspace-write.
#
# Environment variables:
#   CODEX_MODEL   — Model to use (default: gpt-5.3-codex)
#   CODEX_EFFORT  — Reasoning effort: xhigh|high|medium|low (default: xhigh)
#   CODEX_TIMEOUT — Timeout in seconds (default: 120)
#   CODEX_FAIL_CLOSED — 1 to require explicit user confirmation before Claude/Sonnet fallback (default: 1)
#
# Exit codes:
#   0   — Success
#   10  — Rate limited (fallback allowed only when CODEX_FAIL_CLOSED=0)
#   11  — Auth failure (fallback/report allowed only when CODEX_FAIL_CLOSED=0)
#   12  — Timeout (fallback allowed only when CODEX_FAIL_CLOSED=0)
#   13  — CLI not found (fallback/report allowed only when CODEX_FAIL_CLOSED=0)
#   20  — Fail-closed: stop and ask user before Claude/Sonnet fallback
#   1   — Other failure (fallback allowed only when CODEX_FAIL_CLOSED=0)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
METRICS_HELPER="${PLUGIN_ROOT}/hooks/router-metrics.sh"
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

usage_examples() {
    cat >&2 <<'EOF'
Usage:
  codex-runner.sh "<prompt>" [read-only|workspace-write] [working-dir]
  codex-runner.sh "<prompt>" <working-dir> [read-only|workspace-write]   # legacy-compatible

Examples:
  codex-runner.sh "Fix tests" workspace-write /path/to/project
  codex-runner.sh "Fix tests" /path/to/project
  codex-runner.sh "Review changes" /path/to/project read-only
EOF
}

is_sandbox_mode() {
    [[ "$1" == "read-only" || "$1" == "workspace-write" ]]
}

looks_like_path() {
    local value="$1"
    [[ "$value" == /* || "$value" == ./* || "$value" == ../* || "$value" == */* || "$value" == "~" || "$value" == "~/"* ]]
}

PROMPT="${1:?Usage: codex-runner.sh <prompt> [sandbox-mode] [working-dir]}"
ARG2="${2:-}"
ARG3="${3:-}"
SANDBOX="read-only"
WORKDIR="$(pwd)"

if [[ -z "$ARG2" ]]; then
    :
elif is_sandbox_mode "$ARG2"; then
    SANDBOX="$ARG2"
    if [[ -n "$ARG3" ]]; then
        WORKDIR="$ARG3"
    fi
elif is_sandbox_mode "$ARG3"; then
    # Legacy order: <prompt> <working-dir> <sandbox-mode>
    WORKDIR="$ARG2"
    SANDBOX="$ARG3"
elif [[ -d "$ARG2" ]] || looks_like_path "$ARG2"; then
    # Legacy order: <prompt> <working-dir>
    WORKDIR="$ARG2"
    SANDBOX="workspace-write"
    if [[ -n "$ARG3" ]]; then
        echo "ERROR: Invalid sandbox mode '$ARG3'. Allowed: read-only, workspace-write" >&2
        usage_examples
        exit 1
    fi
else
    echo "ERROR: Invalid sandbox mode '$ARG2'. Allowed: read-only, workspace-write" >&2
    usage_examples
    exit 1
fi

# Validate sandbox mode against allowlist
case "$SANDBOX" in
    read-only|workspace-write) ;;
    *)
        echo "ERROR: Invalid sandbox mode '$SANDBOX'. Allowed: read-only, workspace-write" >&2
        usage_examples
        exit 1
        ;;
esac

MODEL="${CODEX_MODEL:-gpt-5.3-codex}"
EFFORT="${CODEX_EFFORT:-xhigh}"
TIMEOUT="${CODEX_TIMEOUT:-120}"
FAIL_CLOSED="${CODEX_FAIL_CLOSED:-1}"
MAX_RETRIES=1

# Validate reasoning effort against allowlist
case "$EFFORT" in
    xhigh|high|medium|low) ;;
    *) echo "ERROR: Invalid CODEX_EFFORT '$EFFORT'. Allowed: xhigh, high, medium, low" >&2; exit 1 ;;
esac

# Validate fail-closed flag
case "$FAIL_CLOSED" in
    0|1) ;;
    *) echo "ERROR: Invalid CODEX_FAIL_CLOSED '$FAIL_CLOSED'. Allowed: 0, 1" >&2; exit 1 ;;
esac

exit_with_fallback_policy() {
    local reason="$1"
    local fallback_exit_code="$2"

    if [[ "$FAIL_CLOSED" == "1" ]]; then
        echo "FAIL_CLOSED: Codex routing failed (${reason})." >&2
        echo "ACTION_REQUIRED: Ask user for explicit confirmation before proceeding on Claude/Sonnet fallback." >&2
        exit 20
    fi

    exit "$fallback_exit_code"
}

metrics_cmd() {
    if [[ ! -x "$METRICS_HELPER" ]]; then
        return 0
    fi
    /bin/bash "$METRICS_HELPER" "$@" >/dev/null 2>&1 || true
}

record_codex_metrics() {
    local jsonl_output="$1"
    if [[ ! -x "$METRICS_HELPER" || -z "$JQ_BIN" || ! -x "$JQ_BIN" ]]; then
        return 0
    fi

    local json_lines usage_line input_tokens cached_input_tokens output_tokens
    json_lines="$(printf '%s\n' "$jsonl_output" | sed -n '/^[[:space:]]*{/p')"

    usage_line="$(
        printf '%s\n' "$json_lines" \
          | "$JQ_BIN" -rc 'select(.type == "turn.completed" and .usage != null) | .usage' 2>/dev/null \
          | tail -n 1
    )"

    if [[ -z "$usage_line" ]]; then
        usage_line="$(
            printf '%s\n' "$json_lines" \
              | "$JQ_BIN" -rc '
                if .type == "token_count" and .info != null then
                  (.info.total_token_usage // .info.last_token_usage // empty)
                elif .payload != null and .payload.type == "token_count" and .payload.info != null then
                  (.payload.info.total_token_usage // .payload.info.last_token_usage // empty)
                else
                  empty
                end
              ' 2>/dev/null \
              | tail -n 1
        )"
    fi

    if [[ -z "$usage_line" ]]; then
        :
    else
        input_tokens="$(printf '%s\n' "$usage_line" | "$JQ_BIN" -r '.input_tokens // 0' 2>/dev/null || echo 0)"
        cached_input_tokens="$(printf '%s\n' "$usage_line" | "$JQ_BIN" -r '.cached_input_tokens // 0' 2>/dev/null || echo 0)"
        output_tokens="$(printf '%s\n' "$usage_line" | "$JQ_BIN" -r '.output_tokens // 0' 2>/dev/null || echo 0)"

        metrics_cmd add_codex "$input_tokens" "$cached_input_tokens" "$output_tokens"
    fi

    local rl_tsv primary_used primary_reset secondary_used secondary_reset
    rl_tsv="$(
        printf '%s\n' "$json_lines" \
          | "$JQ_BIN" -r '
            if .type == "token_count" and .rate_limits != null then
              .rate_limits
            elif .payload != null and .payload.type == "token_count" and .payload.rate_limits != null then
              .payload.rate_limits
            else
              empty
            end
            | [
                (.primary.used_percent // ""),
                (.primary.resets_at // ""),
                (.secondary.used_percent // ""),
                (.secondary.resets_at // "")
              ]
            | @tsv
          ' 2>/dev/null \
          | tail -n 1
    )"

    if [[ -n "$rl_tsv" ]]; then
        IFS=$'\t' read -r primary_used primary_reset secondary_used secondary_reset <<< "$rl_tsv"
        metrics_cmd set_rate_limit codex "${primary_used:-}" "${primary_reset:-}" "${secondary_used:-}" "${secondary_reset:-}"
    fi
}

extract_last_agent_message() {
    local jsonl_output="$1"
    if [[ -z "$JQ_BIN" || ! -x "$JQ_BIN" ]]; then
        printf ''
        return 0
    fi
    printf '%s\n' "$jsonl_output" \
      | sed -n '/^[[:space:]]*{/p' \
      | "$JQ_BIN" -r '
          select(
            .type == "item.completed"
            and .item != null
            and .item.type == "agent_message"
            and .item.text != null
          ) | .item.text
        ' 2>/dev/null \
      | tail -n 1
}

# Validate working directory exists
if [[ ! -d "$WORKDIR" ]]; then
    echo "ERROR: Working directory does not exist: $WORKDIR" >&2
    usage_examples
    exit 1
fi

# Check if codex is installed
if ! command -v codex &>/dev/null; then
    echo "ERROR: codex CLI not found. Install with: npm install -g @openai/codex" >&2
    exit_with_fallback_policy "codex CLI not found" 13
fi

run_codex() {
    local output_last_message_file="$1"
    _timeout "${TIMEOUT}" codex exec \
        -m "$MODEL" \
        --config "model_reasoning_effort=\"${EFFORT}\"" \
        --sandbox "$SANDBOX" \
        --full-auto \
        --skip-git-repo-check \
        --json \
        --output-last-message "$output_last_message_file" \
        -C "$WORKDIR" \
        "$PROMPT"
}

attempt=0
while (( attempt <= MAX_RETRIES )); do
    metrics_cmd mark_attempt codex
    message_file="$(mktemp)"
    set +e
    output=$(run_codex "$message_file" 2>&1)
    exit_code=$?
    set -e

    record_codex_metrics "$output"

    if (( exit_code == 0 )); then
        metrics_cmd mark_success codex
        final_output=""
        if [[ -s "$message_file" ]]; then
            final_output="$(cat "$message_file")"
        fi
        if [[ -z "$final_output" ]]; then
            final_output="$(extract_last_agent_message "$output")"
        fi
        rm -f "$message_file"
        echo "$final_output"
        exit 0
    fi
    rm -f "$message_file"

    # Check for rate limit
    if echo "$output" | grep -qi "429\|rate.limit\|too many requests"; then
        metrics_cmd mark_failure codex "$exit_code" "rate_limited"
        if (( attempt < MAX_RETRIES )); then
            echo "RETRY: Codex rate limited, waiting 30s..." >&2
            sleep 30
            ((attempt++))
            continue
        fi
        echo "ERROR: Codex rate limited after $((attempt + 1)) attempts." >&2
        echo "${output:0:500}" >&2
        exit_with_fallback_policy "rate limited" 10
    fi

    # Check for auth failure
    if echo "$output" | grep -qi "auth\|unauthorized\|403\|login\|credential"; then
        metrics_cmd mark_failure codex "$exit_code" "authentication_failure"
        echo "ERROR: Codex authentication failure. Run 'codex login' to fix." >&2
        echo "${output:0:500}" >&2
        exit_with_fallback_policy "authentication failure" 11
    fi

    # Check for timeout
    if (( exit_code == 124 )); then
        metrics_cmd mark_failure codex "$exit_code" "timeout"
        echo "ERROR: Codex timed out after ${TIMEOUT}s." >&2
        exit_with_fallback_policy "timeout" 12
    fi

    # Other failure
    metrics_cmd mark_failure codex "$exit_code" "general_failure"
    if (( attempt < MAX_RETRIES )); then
        ((attempt++))
        continue
    fi

    echo "ERROR: Codex failed (exit code: $exit_code)." >&2
    echo "${output:0:500}" >&2
    exit_with_fallback_policy "general failure" 1
done
