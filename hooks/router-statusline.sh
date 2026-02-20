#!/usr/bin/env bash
# router-statusline.sh — compact statusline indicator for deferred tokens.

set -euo pipefail

# Some statusline integrations pipe JSON input to commands. We don't need it.
if [[ ! -t 0 ]]; then
    cat >/dev/null || true
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
METRICS_HELPER="${SCRIPT_DIR}/router-metrics.sh"
JQ_BIN="/usr/bin/jq"
if [[ ! -x "$JQ_BIN" ]]; then
    JQ_BIN="$(command -v jq || true)"
fi

format_tokens() {
    local n="$1"
    if (( n >= 1000000 )); then
        printf "%dm" "$((n / 1000000))"
    elif (( n >= 1000 )); then
        printf "%dk" "$((n / 1000))"
    else
        printf "%d" "$n"
    fi
}

zero_line() {
    printf 'Offload C:0 G:0 Σ:0\n'
}

if [[ ! -x "$METRICS_HELPER" ]]; then
    zero_line
    exit 0
fi

metrics_json="$(/bin/bash "$METRICS_HELPER" read 2>/dev/null || true)"
if [[ -z "$metrics_json" ]]; then
    zero_line
    exit 0
fi

if [[ -z "$JQ_BIN" || ! -x "$JQ_BIN" ]]; then
    zero_line
    exit 0
fi

read -r codex_total gemini_total deferred_total < <(
    printf '%s\n' "$metrics_json" | "$JQ_BIN" -r '
        [
          (.codex.total_tokens // 0),
          (.gemini.total_tokens // 0),
          (.totals.deferred_tokens // 0)
        ] | @tsv
    ' 2>/dev/null || printf '0\t0\t0\n'
)

codex_fmt="$(format_tokens "${codex_total:-0}")"
gemini_fmt="$(format_tokens "${gemini_total:-0}")"
deferred_fmt="$(format_tokens "${deferred_total:-0}")"

printf 'Offload C:%s G:%s Σ:%s\n' "$codex_fmt" "$gemini_fmt" "$deferred_fmt"
