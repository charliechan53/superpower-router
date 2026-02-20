#!/usr/bin/env bash
# router-metrics.sh — track per-session offloaded token usage for Codex/Gemini.

set -euo pipefail

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
  "version": 1,
  "session_started_at": "${ts}",
  "updated_at": "${ts}",
  "codex": {
    "runs": 0,
    "input_tokens": 0,
    "cached_input_tokens": 0,
    "output_tokens": 0,
    "total_tokens": 0
  },
  "gemini": {
    "runs": 0,
    "input_tokens": 0,
    "prompt_tokens": 0,
    "candidates_tokens": 0,
    "thoughts_tokens": 0,
    "tool_tokens": 0,
    "cached_tokens": 0,
    "total_tokens": 0
  },
  "totals": {
    "deferred_tokens": 0,
    "estimated_claude_saved_tokens": 0
  }
}
EOF
}

ensure_parent_dir() {
    local file="$1"
    mkdir -p "$(dirname "$file")"
}

ensure_metrics_file() {
    local file
    file="$(metrics_file)"
    ensure_parent_dir "$file"

    if [[ ! -f "$file" ]]; then
        init_json "$(now_iso_utc)" > "$file"
        return
    fi

    if ! jq empty "$file" >/dev/null 2>&1; then
        init_json "$(now_iso_utc)" > "$file"
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

write_tmp_then_move() {
    local target="$1"
    local tmp
    tmp="$(mktemp "${target}.XXXXXX")"
    cat > "$tmp"
    mv "$tmp" "$target"
}

add_codex_usage() {
    local input_tokens cached_input_tokens output_tokens
    input_tokens="$(sanitize_int "${1:-0}")"
    cached_input_tokens="$(sanitize_int "${2:-0}")"
    output_tokens="$(sanitize_int "${3:-0}")"

    ensure_metrics_file
    local file updated_at
    file="$(metrics_file)"
    updated_at="$(now_iso_utc)"

    jq \
      --argjson input_tokens "$input_tokens" \
      --argjson cached_input_tokens "$cached_input_tokens" \
      --argjson output_tokens "$output_tokens" \
      --arg updated_at "$updated_at" \
      '
      .codex.runs += 1
      | .codex.input_tokens += $input_tokens
      | .codex.cached_input_tokens += $cached_input_tokens
      | .codex.output_tokens += $output_tokens
      | .codex.total_tokens += ($input_tokens + $output_tokens)
      | .totals.deferred_tokens = (.codex.total_tokens + .gemini.total_tokens)
      | .totals.estimated_claude_saved_tokens = .totals.deferred_tokens
      | .updated_at = $updated_at
      ' "$file" | write_tmp_then_move "$file"
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

    ensure_metrics_file
    local file updated_at
    file="$(metrics_file)"
    updated_at="$(now_iso_utc)"

    jq \
      --argjson input_tokens "$input_tokens" \
      --argjson prompt_tokens "$prompt_tokens" \
      --argjson candidates_tokens "$candidates_tokens" \
      --argjson thoughts_tokens "$thoughts_tokens" \
      --argjson tool_tokens "$tool_tokens" \
      --argjson cached_tokens "$cached_tokens" \
      --argjson total_tokens "$total_tokens" \
      --arg updated_at "$updated_at" \
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
      | .updated_at = $updated_at
      ' "$file" | write_tmp_then_move "$file"
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
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
