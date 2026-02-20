#!/usr/bin/env bash
# router-metrics.sh — track per-session offloaded token usage for Codex/Gemini.

set -euo pipefail

SCHEMA_VERSION=2

JQ_BIN="/usr/bin/jq"
if [[ ! -x "$JQ_BIN" ]]; then
    JQ_BIN="$(command -v jq || true)"
fi

has_jq() {
    [[ -n "$JQ_BIN" && -x "$JQ_BIN" ]]
}

metrics_file() {
    local default_path="${TMPDIR:-/tmp}/superpower-router-metrics-${USER:-user}.json"
    printf '%s\n' "${ROUTER_METRICS_FILE:-$default_path}"
}

now_iso_utc() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

init_json() {
    local ts="$1"
    cat <<EOF
{
  "version": ${SCHEMA_VERSION},
  "session_started_at": "${ts}",
  "updated_at": "${ts}",
  "codex": {
    "runs": 0,
    "attempts": 0,
    "successes": 0,
    "failures": 0,
    "input_tokens": 0,
    "cached_input_tokens": 0,
    "output_tokens": 0,
    "total_tokens": 0,
    "last_exit_code": null,
    "last_error_reason": null,
    "last_error_at": null,
    "rate_limit": {
      "primary": {
        "used_percent": null,
        "remaining_percent": null,
        "resets_at": null
      },
      "secondary": {
        "used_percent": null,
        "remaining_percent": null,
        "resets_at": null
      },
      "updated_at": null
    }
  },
  "gemini": {
    "runs": 0,
    "attempts": 0,
    "successes": 0,
    "failures": 0,
    "input_tokens": 0,
    "prompt_tokens": 0,
    "candidates_tokens": 0,
    "thoughts_tokens": 0,
    "tool_tokens": 0,
    "cached_tokens": 0,
    "total_tokens": 0,
    "last_exit_code": null,
    "last_error_reason": null,
    "last_error_at": null,
    "rate_limit": {
      "remaining_percent": null,
      "resets_at": null,
      "retry_after_seconds": null,
      "status": null,
      "updated_at": null
    }
  },
  "totals": {
    "deferred_tokens": 0,
    "estimated_claude_saved_tokens": 0,
    "attempts": 0,
    "successes": 0,
    "failures": 0
  }
}
EOF
}

ensure_parent_dir() {
    local file="$1"
    mkdir -p "$(dirname "$file")"
}

ensure_schema_v2() {
    local file="$1"
    if ! has_jq; then
        return 0
    fi

    local version
    version="$("$JQ_BIN" -r '.version // 0' "$file" 2>/dev/null || echo 0)"
    if [[ "$version" == "${SCHEMA_VERSION}" ]]; then
        return 0
    fi

    "$JQ_BIN" '
      def with_codex_defaults:
        {
          runs: 0,
          attempts: 0,
          successes: 0,
          failures: 0,
          input_tokens: 0,
          cached_input_tokens: 0,
          output_tokens: 0,
          total_tokens: 0,
          last_exit_code: null,
          last_error_reason: null,
          last_error_at: null,
          rate_limit: {
            primary: {
              used_percent: null,
              remaining_percent: null,
              resets_at: null
            },
            secondary: {
              used_percent: null,
              remaining_percent: null,
              resets_at: null
            },
            updated_at: null
          }
        } + (. // {});
      def with_gemini_defaults:
        {
          runs: 0,
          attempts: 0,
          successes: 0,
          failures: 0,
          input_tokens: 0,
          prompt_tokens: 0,
          candidates_tokens: 0,
          thoughts_tokens: 0,
          tool_tokens: 0,
          cached_tokens: 0,
          total_tokens: 0,
          last_exit_code: null,
          last_error_reason: null,
          last_error_at: null,
          rate_limit: {
            remaining_percent: null,
            resets_at: null,
            retry_after_seconds: null,
            status: null,
            updated_at: null
          }
        } + (. // {});
      .version = 2
      | .session_started_at = (.session_started_at // .updated_at // (now | todateiso8601))
      | .updated_at = (.updated_at // (now | todateiso8601))
      | .codex = (.codex | with_codex_defaults)
      | .gemini = (.gemini | with_gemini_defaults)
      | .totals = (
          {
            deferred_tokens: 0,
            estimated_claude_saved_tokens: 0,
            attempts: 0,
            successes: 0,
            failures: 0
          } + (.totals // {})
        )
      | .totals.deferred_tokens = ((.codex.total_tokens // 0) + (.gemini.total_tokens // 0))
      | .totals.estimated_claude_saved_tokens = .totals.deferred_tokens
      | .totals.attempts = ((.codex.attempts // 0) + (.gemini.attempts // 0))
      | .totals.successes = ((.codex.successes // 0) + (.gemini.successes // 0))
      | .totals.failures = ((.codex.failures // 0) + (.gemini.failures // 0))
    ' "$file" | write_tmp_then_move "$file"
}

ensure_metrics_file() {
    local file
    file="$(metrics_file)"
    ensure_parent_dir "$file"

    if [[ ! -f "$file" ]]; then
        init_json "$(now_iso_utc)" > "$file"
        return
    fi

    if has_jq; then
        if ! "$JQ_BIN" empty "$file" >/dev/null 2>&1; then
            init_json "$(now_iso_utc)" > "$file"
            return
        fi
        ensure_schema_v2 "$file"
    fi
}

reset_metrics() {
    local file
    file="$(metrics_file)"
    ensure_parent_dir "$file"
    init_json "$(now_iso_utc)" > "$file"
}

sanitize_int() {
    local value="${1:-0}"
    if [[ "$value" =~ ^[0-9]+$ ]]; then
        printf '%s\n' "$value"
    else
        printf '0\n'
    fi
}

sanitize_exit_code() {
    local value="${1:-1}"
    if [[ "$value" =~ ^-?[0-9]+$ ]]; then
        printf '%s\n' "$value"
    else
        printf '1\n'
    fi
}

sanitize_number() {
    local value="${1:-}"
    if [[ "$value" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
        printf '%s\n' "$value"
    else
        printf 'null\n'
    fi
}

sanitize_nullable_int() {
    local value="${1:-}"
    if [[ "$value" =~ ^[0-9]+$ ]]; then
        printf '%s\n' "$value"
    else
        printf 'null\n'
    fi
}

sanitize_rate_status() {
    local value="${1:-}"
    # Keep status compact to avoid large statusline payloads.
    value="${value//$'\n'/ }"
    value="${value//$'\r'/ }"
    value="${value//$'\t'/ }"
    printf '%s\n' "$value"
}

write_tmp_then_move() {
    local target="$1"
    local tmp
    tmp="$(mktemp "${target}.XXXXXX")"
    cat > "$tmp"
    mv "$tmp" "$target"
}

apply_update() {
    local jq_filter="$1"
    shift

    ensure_metrics_file
    if ! has_jq; then
        return 0
    fi

    local file updated_at
    file="$(metrics_file)"
    updated_at="$(now_iso_utc)"

    "$JQ_BIN" \
      --arg updated_at "$updated_at" \
      "$@" \
      "$jq_filter" \
      "$file" | write_tmp_then_move "$file"
}

add_codex_usage() {
    local input_tokens cached_input_tokens output_tokens
    input_tokens="$(sanitize_int "${1:-0}")"
    cached_input_tokens="$(sanitize_int "${2:-0}")"
    output_tokens="$(sanitize_int "${3:-0}")"

    apply_update \
      '
      .codex.runs += 1
      | .codex.input_tokens += $input_tokens
      | .codex.cached_input_tokens += $cached_input_tokens
      | .codex.output_tokens += $output_tokens
      | .codex.total_tokens += ($input_tokens + $output_tokens)
      | .totals.deferred_tokens = (.codex.total_tokens + .gemini.total_tokens)
      | .totals.estimated_claude_saved_tokens = .totals.deferred_tokens
      | .totals.attempts = (.codex.attempts + .gemini.attempts)
      | .totals.successes = (.codex.successes + .gemini.successes)
      | .totals.failures = (.codex.failures + .gemini.failures)
      | .updated_at = $updated_at
      ' \
      --argjson input_tokens "$input_tokens" \
      --argjson cached_input_tokens "$cached_input_tokens" \
      --argjson output_tokens "$output_tokens"
}

add_gemini_usage() {
    local input_tokens prompt_tokens candidates_tokens thoughts_tokens tool_tokens cached_tokens total_tokens
    input_tokens="$(sanitize_int "${1:-0}")"
    prompt_tokens="$(sanitize_int "${2:-0}")"
    candidates_tokens="$(sanitize_int "${3:-0}")"
    thoughts_tokens="$(sanitize_int "${4:-0}")"
    tool_tokens="$(sanitize_int "${5:-0}")"
    cached_tokens="$(sanitize_int "${6:-0}")"
    total_tokens="$(sanitize_int "${7:-0}")"

    apply_update \
      '
      .gemini.runs += 1
      | .gemini.input_tokens += $input_tokens
      | .gemini.prompt_tokens += $prompt_tokens
      | .gemini.candidates_tokens += $candidates_tokens
      | .gemini.thoughts_tokens += $thoughts_tokens
      | .gemini.tool_tokens += $tool_tokens
      | .gemini.cached_tokens += $cached_tokens
      | .gemini.total_tokens += $total_tokens
      | .totals.deferred_tokens = (.codex.total_tokens + .gemini.total_tokens)
      | .totals.estimated_claude_saved_tokens = .totals.deferred_tokens
      | .totals.attempts = (.codex.attempts + .gemini.attempts)
      | .totals.successes = (.codex.successes + .gemini.successes)
      | .totals.failures = (.codex.failures + .gemini.failures)
      | .updated_at = $updated_at
      ' \
      --argjson input_tokens "$input_tokens" \
      --argjson prompt_tokens "$prompt_tokens" \
      --argjson candidates_tokens "$candidates_tokens" \
      --argjson thoughts_tokens "$thoughts_tokens" \
      --argjson tool_tokens "$tool_tokens" \
      --argjson cached_tokens "$cached_tokens" \
      --argjson total_tokens "$total_tokens"
}

validate_backend() {
    local backend="${1:-}"
    [[ "$backend" == "codex" || "$backend" == "gemini" ]]
}

mark_attempt() {
    local backend="${1:-}"
    if ! validate_backend "$backend"; then
        return 1
    fi

    apply_update \
      '
      .[$backend].attempts += 1
      | .totals.attempts = (.codex.attempts + .gemini.attempts)
      | .totals.successes = (.codex.successes + .gemini.successes)
      | .totals.failures = (.codex.failures + .gemini.failures)
      | .updated_at = $updated_at
      ' \
      --arg backend "$backend"
}

mark_success() {
    local backend="${1:-}"
    if ! validate_backend "$backend"; then
        return 1
    fi

    apply_update \
      '
      .[$backend].successes += 1
      | .totals.attempts = (.codex.attempts + .gemini.attempts)
      | .totals.successes = (.codex.successes + .gemini.successes)
      | .totals.failures = (.codex.failures + .gemini.failures)
      | .updated_at = $updated_at
      ' \
      --arg backend "$backend"
}

mark_failure() {
    local backend="${1:-}"
    local exit_code reason
    exit_code="$(sanitize_exit_code "${2:-1}")"
    reason="$(sanitize_rate_status "${3:-unknown}")"
    if ! validate_backend "$backend"; then
        return 1
    fi

    apply_update \
      '
      .[$backend].failures += 1
      | .[$backend].last_exit_code = $exit_code
      | .[$backend].last_error_reason = $reason
      | .[$backend].last_error_at = $updated_at
      | .totals.attempts = (.codex.attempts + .gemini.attempts)
      | .totals.successes = (.codex.successes + .gemini.successes)
      | .totals.failures = (.codex.failures + .gemini.failures)
      | .updated_at = $updated_at
      ' \
      --arg backend "$backend" \
      --argjson exit_code "$exit_code" \
      --arg reason "$reason"
}

set_rate_limit_codex() {
    local primary_used primary_resets secondary_used secondary_resets
    primary_used="$(sanitize_number "${1:-}")"
    primary_resets="$(sanitize_nullable_int "${2:-}")"
    secondary_used="$(sanitize_number "${3:-}")"
    secondary_resets="$(sanitize_nullable_int "${4:-}")"

    apply_update \
      '
      .codex.rate_limit.primary.used_percent = $primary_used
      | .codex.rate_limit.primary.remaining_percent =
          (if $primary_used == null then null else ([0, (100 - ($primary_used | tonumber))] | max) end)
      | .codex.rate_limit.primary.resets_at = $primary_resets
      | .codex.rate_limit.secondary.used_percent = $secondary_used
      | .codex.rate_limit.secondary.remaining_percent =
          (if $secondary_used == null then null else ([0, (100 - ($secondary_used | tonumber))] | max) end)
      | .codex.rate_limit.secondary.resets_at = $secondary_resets
      | .codex.rate_limit.updated_at = $updated_at
      | .updated_at = $updated_at
      ' \
      --argjson primary_used "$primary_used" \
      --argjson primary_resets "$primary_resets" \
      --argjson secondary_used "$secondary_used" \
      --argjson secondary_resets "$secondary_resets"
}

set_rate_limit_gemini() {
    local retry_after status remaining_percent resets_at
    retry_after="$(sanitize_number "${1:-}")"
    status="$(sanitize_rate_status "${2:-}")"
    remaining_percent="$(sanitize_number "${3:-}")"
    resets_at="$(sanitize_nullable_int "${4:-}")"

    apply_update \
      '
      .gemini.rate_limit.retry_after_seconds = $retry_after
      | .gemini.rate_limit.status = (if ($status | length) > 0 then $status else .gemini.rate_limit.status end)
      | .gemini.rate_limit.remaining_percent = $remaining_percent
      | .gemini.rate_limit.resets_at = $resets_at
      | .gemini.rate_limit.updated_at = $updated_at
      | .updated_at = $updated_at
      ' \
      --argjson retry_after "$retry_after" \
      --arg status "$status" \
      --argjson remaining_percent "$remaining_percent" \
      --argjson resets_at "$resets_at"
}

set_rate_limit() {
    local backend="${1:-}"
    shift || true
    case "$backend" in
        codex)
            set_rate_limit_codex "${1:-}" "${2:-}" "${3:-}" "${4:-}"
            ;;
        gemini)
            set_rate_limit_gemini "${1:-}" "${2:-}" "${3:-}" "${4:-}"
            ;;
        *)
            return 1
            ;;
    esac
}

print_metrics() {
    ensure_metrics_file
    cat "$(metrics_file)"
}

usage() {
    cat >&2 <<'EOF'
Usage:
  router-metrics.sh reset
  router-metrics.sh read
  router-metrics.sh add_codex <input_tokens> <cached_input_tokens> <output_tokens>
  router-metrics.sh add_gemini <input_tokens> <prompt_tokens> <candidates_tokens> <thoughts_tokens> <tool_tokens> <cached_tokens> <total_tokens>
  router-metrics.sh mark_attempt <codex|gemini>
  router-metrics.sh mark_success <codex|gemini>
  router-metrics.sh mark_failure <codex|gemini> <exit_code> <reason>
  router-metrics.sh set_rate_limit codex <primary_used_percent> <primary_resets_at_epoch> <secondary_used_percent> <secondary_resets_at_epoch>
  router-metrics.sh set_rate_limit gemini <retry_after_seconds> <status> [remaining_percent] [resets_at_epoch]
EOF
}

main() {
    local cmd="${1:-}"
    case "$cmd" in
        reset)
            reset_metrics
            ;;
        read)
            print_metrics
            ;;
        add_codex)
            shift
            add_codex_usage "${1:-0}" "${2:-0}" "${3:-0}"
            ;;
        add_gemini)
            shift
            add_gemini_usage "${1:-0}" "${2:-0}" "${3:-0}" "${4:-0}" "${5:-0}" "${6:-0}" "${7:-0}"
            ;;
        mark_attempt)
            shift
            mark_attempt "${1:-}"
            ;;
        mark_success)
            shift
            mark_success "${1:-}"
            ;;
        mark_failure)
            shift
            mark_failure "${1:-}" "${2:-1}" "${3:-unknown}"
            ;;
        set_rate_limit)
            shift
            set_rate_limit "${1:-}" "${2:-}" "${3:-}" "${4:-}" "${5:-}"
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
