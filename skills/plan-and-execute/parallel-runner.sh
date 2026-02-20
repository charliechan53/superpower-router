#!/usr/bin/env bash
# parallel-runner.sh — Run Codex and Gemini prompts concurrently and return combined output.
#
# Usage:
#   parallel-runner.sh "<shared-prompt>" [working-dir] [read-only|workspace-write]
#   parallel-runner.sh --codex-prompt "<prompt>" --gemini-prompt "<prompt>" [--workdir DIR] [--codex-sandbox MODE]
#
# Exit code precedence:
#   20 (Codex fail-closed) > non-zero Codex exit > non-zero Gemini exit > 0

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
CODEX_RUNNER="${SCRIPT_DIR}/codex-runner.sh"
GEMINI_RUNNER="${SCRIPT_DIR}/gemini-runner.sh"

usage() {
    cat >&2 <<'EOF'
Usage:
  parallel-runner.sh "<shared-prompt>" [working-dir] [read-only|workspace-write]
  parallel-runner.sh --codex-prompt "<prompt>" --gemini-prompt "<prompt>" [--workdir DIR] [--codex-sandbox MODE]

Examples:
  parallel-runner.sh "Propose 3 implementation options for feature X" /path/to/repo read-only
  parallel-runner.sh --codex-prompt "Review trade-offs in this repo" --gemini-prompt "Research latest best practices"
EOF
}

is_sandbox_mode() {
    [[ "$1" == "read-only" || "$1" == "workspace-write" ]]
}

SHARED_PROMPT=""
CODEX_PROMPT=""
GEMINI_PROMPT=""
WORKDIR="$(pwd)"
CODEX_SANDBOX="read-only"
GEMINI_MODEL="${GEMINI_MODEL:-}"

POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --codex-prompt)
            CODEX_PROMPT="${2:-}"
            shift 2
            ;;
        --gemini-prompt)
            GEMINI_PROMPT="${2:-}"
            shift 2
            ;;
        --workdir)
            WORKDIR="${2:-}"
            shift 2
            ;;
        --codex-sandbox)
            CODEX_SANDBOX="${2:-}"
            shift 2
            ;;
        --gemini-model)
            GEMINI_MODEL="${2:-}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

if [[ ${#POSITIONAL[@]} -gt 0 ]]; then
    if [[ -z "$CODEX_PROMPT" && -z "$GEMINI_PROMPT" ]]; then
        SHARED_PROMPT="${POSITIONAL[0]}"
    else
        echo "ERROR: Positional prompt cannot be combined with --codex-prompt/--gemini-prompt." >&2
        usage
        exit 1
    fi
fi

if [[ ${#POSITIONAL[@]} -gt 1 ]]; then
    WORKDIR="${POSITIONAL[1]}"
fi
if [[ ${#POSITIONAL[@]} -gt 2 ]]; then
    CODEX_SANDBOX="${POSITIONAL[2]}"
fi
if [[ ${#POSITIONAL[@]} -gt 3 ]]; then
    echo "ERROR: Too many positional arguments." >&2
    usage
    exit 1
fi

if [[ -n "$SHARED_PROMPT" ]]; then
    CODEX_PROMPT="$SHARED_PROMPT"
    GEMINI_PROMPT="$SHARED_PROMPT"
fi

if [[ -z "$CODEX_PROMPT" && -z "$GEMINI_PROMPT" ]]; then
    echo "ERROR: No prompt provided for Codex or Gemini." >&2
    usage
    exit 1
fi

if [[ ! -d "$WORKDIR" ]]; then
    echo "ERROR: Working directory does not exist: $WORKDIR" >&2
    exit 1
fi

if ! is_sandbox_mode "$CODEX_SANDBOX"; then
    echo "ERROR: Invalid codex sandbox mode '$CODEX_SANDBOX'. Allowed: read-only, workspace-write" >&2
    exit 1
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

start_job() {
    local name="$1"
    shift
    (
        set +e
        "$@" >"${TMP_DIR}/${name}.out" 2>"${TMP_DIR}/${name}.err"
        echo $? >"${TMP_DIR}/${name}.code"
    ) &
    JOB_PID=$!
}

write_missing_runner_result() {
    local name="$1"
    local path="$2"
    : >"${TMP_DIR}/${name}.out"
    printf 'ERROR: %s is not executable: %s\n' "$name" "$path" >"${TMP_DIR}/${name}.err"
    echo 13 >"${TMP_DIR}/${name}.code"
}

codex_requested=0
gemini_requested=0
codex_pid=""
gemini_pid=""

if [[ -n "$CODEX_PROMPT" ]]; then
    codex_requested=1
    if [[ -x "$CODEX_RUNNER" ]]; then
        start_job codex /bin/bash "$CODEX_RUNNER" "$CODEX_PROMPT" "$CODEX_SANDBOX" "$WORKDIR"
        codex_pid="$JOB_PID"
    else
        write_missing_runner_result "codex" "$CODEX_RUNNER"
    fi
fi

if [[ -n "$GEMINI_PROMPT" ]]; then
    gemini_requested=1
    if [[ -x "$GEMINI_RUNNER" ]]; then
        if [[ -n "$GEMINI_MODEL" ]]; then
            start_job gemini /bin/bash "$GEMINI_RUNNER" "$GEMINI_PROMPT" "$GEMINI_MODEL"
            gemini_pid="$JOB_PID"
        else
            start_job gemini /bin/bash "$GEMINI_RUNNER" "$GEMINI_PROMPT"
            gemini_pid="$JOB_PID"
        fi
    else
        write_missing_runner_result "gemini" "$GEMINI_RUNNER"
    fi
fi

if [[ -n "$codex_pid" ]]; then
    wait "$codex_pid" || true
fi
if [[ -n "$gemini_pid" ]]; then
    wait "$gemini_pid" || true
fi

codex_exit=0
gemini_exit=0
if [[ "$codex_requested" == "1" ]]; then
    codex_exit="$(cat "${TMP_DIR}/codex.code" 2>/dev/null || echo 1)"
fi
if [[ "$gemini_requested" == "1" ]]; then
    gemini_exit="$(cat "${TMP_DIR}/gemini.code" 2>/dev/null || echo 1)"
fi

echo "=== PARALLEL RUN SUMMARY ==="
echo "workdir=${WORKDIR}"
echo "codex_requested=${codex_requested} codex_exit=${codex_exit}"
echo "gemini_requested=${gemini_requested} gemini_exit=${gemini_exit}"

if [[ "$codex_requested" == "1" ]]; then
    echo
    echo "=== CODEX OUTPUT (exit ${codex_exit}) ==="
    cat "${TMP_DIR}/codex.out" 2>/dev/null || true
    if [[ -s "${TMP_DIR}/codex.err" ]]; then
        echo
        echo "=== CODEX ERROR ==="
        cat "${TMP_DIR}/codex.err"
    fi
fi

if [[ "$gemini_requested" == "1" ]]; then
    echo
    echo "=== GEMINI OUTPUT (exit ${gemini_exit}) ==="
    cat "${TMP_DIR}/gemini.out" 2>/dev/null || true
    if [[ -s "${TMP_DIR}/gemini.err" ]]; then
        echo
        echo "=== GEMINI ERROR ==="
        cat "${TMP_DIR}/gemini.err"
    fi
fi

if [[ "$codex_requested" == "1" && "$codex_exit" == "20" ]]; then
    exit 20
fi
if [[ "$codex_requested" == "1" && "$codex_exit" != "0" ]]; then
    exit "$codex_exit"
fi
if [[ "$gemini_requested" == "1" && "$gemini_exit" != "0" ]]; then
    exit "$gemini_exit"
fi

exit 0
