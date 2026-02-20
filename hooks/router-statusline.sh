#!/usr/bin/env bash
# router-statusline.sh — compact statusline indicator for offload and backend health.

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
    printf 'Offload C:0 G:0 Σ:0 | S/F C:0/0 G:0/0 | RL C:N/A G:N/A\n'
}

is_number() {
    local n="${1:-}"
    [[ "$n" =~ ^-?[0-9]+([.][0-9]+)?$ ]]
}

format_percent() {
    local n="${1:-}"
    if ! is_number "$n"; then
        printf ''
        return
    fi
    awk -v x="$n" 'BEGIN { if (x < 0) x = 0; if (x > 100) x = 100; printf "%.0f", x }'
}

format_epoch_hhmm() {
    local ts="${1:-}"
    if [[ ! "$ts" =~ ^[0-9]+$ ]]; then
        printf ''
        return
    fi
    if date -r "$ts" "+%H:%M" >/dev/null 2>&1; then
        date -r "$ts" "+%H:%M"
    elif date -d "@$ts" "+%H:%M" >/dev/null 2>&1; then
        date -d "@$ts" "+%H:%M"
    else
        printf ''
    fi
}

format_codex_rl() {
    local remaining="${1:-}"
    local resets_at="${2:-}"
    local pct reset_hhmm

    pct="$(format_percent "$remaining")"
    if [[ -z "$pct" ]]; then
        printf 'N/A'
        return
    fi

    reset_hhmm="$(format_epoch_hhmm "$resets_at")"
    if [[ -n "$reset_hhmm" ]]; then
        printf '%s%%@%s' "$pct" "$reset_hhmm"
    else
        printf '%s%%' "$pct"
    fi
}

format_gemini_rl() {
    local retry_after="${1:-}"
    local remaining="${2:-}"
    local resets_at="${3:-}"
    local pct reset_hhmm rounded_retry

    if is_number "$retry_after"; then
        rounded_retry="$(awk -v x="$retry_after" 'BEGIN { if (x < 0) x = 0; printf "%.0f", x }')"
        if [[ "$rounded_retry" != "0" ]]; then
            printf '~%ss' "$rounded_retry"
            return
        fi
    fi

    pct="$(format_percent "$remaining")"
    if [[ -z "$pct" ]]; then
        printf 'N/A'
        return
    fi

    reset_hhmm="$(format_epoch_hhmm "$resets_at")"
    if [[ -n "$reset_hhmm" ]]; then
        printf '%s%%@%s' "$pct" "$reset_hhmm"
    else
        printf '%s%%' "$pct"
    fi
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

read -r \
    codex_total gemini_total deferred_total \
    codex_successes codex_failures gemini_successes gemini_failures \
    codex_rl_remaining codex_rl_resets_at \
    gemini_rl_retry gemini_rl_remaining gemini_rl_resets_at < <(
    printf '%s\n' "$metrics_json" | "$JQ_BIN" -r '
        [
          (.codex.total_tokens // 0),
          (.gemini.total_tokens // 0),
          (.totals.deferred_tokens // 0),
          (.codex.successes // 0),
          (.codex.failures // 0),
          (.gemini.successes // 0),
          (.gemini.failures // 0),
          (.codex.rate_limit.primary.remaining_percent // ""),
          (.codex.rate_limit.primary.resets_at // ""),
          (.gemini.rate_limit.retry_after_seconds // ""),
          (.gemini.rate_limit.remaining_percent // ""),
          (.gemini.rate_limit.resets_at // "")
        ] | @tsv
    ' 2>/dev/null || printf '0\t0\t0\t0\t0\t0\t0\t\t\t\t\t\n'
)

codex_fmt="$(format_tokens "${codex_total:-0}")"
gemini_fmt="$(format_tokens "${gemini_total:-0}")"
deferred_fmt="$(format_tokens "${deferred_total:-0}")"
codex_rl_fmt="$(format_codex_rl "${codex_rl_remaining:-}" "${codex_rl_resets_at:-}")"
gemini_rl_fmt="$(format_gemini_rl "${gemini_rl_retry:-}" "${gemini_rl_remaining:-}" "${gemini_rl_resets_at:-}")"

printf 'Offload C:%s G:%s Σ:%s | S/F C:%s/%s G:%s/%s | RL C:%s G:%s\n' \
    "$codex_fmt" \
    "$gemini_fmt" \
    "$deferred_fmt" \
    "${codex_successes:-0}" \
    "${codex_failures:-0}" \
    "${gemini_successes:-0}" \
    "${gemini_failures:-0}" \
    "$codex_rl_fmt" \
    "$gemini_rl_fmt"
