#!/usr/bin/env bash
# SessionStart hook for superpower-router plugin (all-in-one: superpowers + codex + gemini routing)

set -euo pipefail

# Determine plugin root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
METRICS_HELPER="${PLUGIN_ROOT}/hooks/router-metrics.sh"
CODEX_RUNNER="${PLUGIN_ROOT}/skills/plan-and-execute/codex-runner.sh"
GEMINI_RUNNER="${PLUGIN_ROOT}/skills/plan-and-execute/gemini-runner.sh"
CLAUDE_HOME="${HOME}/.claude"
CLAUDE_CODEX_SHIM="${CLAUDE_HOME}/codex-runner.sh"
CLAUDE_GEMINI_SHIM="${CLAUDE_HOME}/gemini-runner.sh"

# Initialize metrics file on session start. Do not reset by default because
# SessionStart also fires on resume/compact in many workflows.
# Set ROUTER_RESET_ON_SESSION_START=1 to force reset behavior.
if [[ -x "$METRICS_HELPER" ]]; then
    if [[ "${ROUTER_RESET_ON_SESSION_START:-0}" == "1" ]]; then
        /bin/bash "$METRICS_HELPER" reset >/dev/null 2>&1 || true
    else
        /bin/bash "$METRICS_HELPER" read >/dev/null 2>&1 || true
    fi
fi

# Compatibility shims: some prompts/tools call ~/.claude/{codex,gemini}-runner.sh.
# Keep these symlinks up to date with this plugin install path.
mkdir -p "$CLAUDE_HOME" >/dev/null 2>&1 || true
if [[ -x "$CODEX_RUNNER" ]]; then
    ln -sfn "$CODEX_RUNNER" "$CLAUDE_CODEX_SHIM" >/dev/null 2>&1 || true
fi
if [[ -x "$GEMINI_RUNNER" ]]; then
    ln -sfn "$GEMINI_RUNNER" "$CLAUDE_GEMINI_SHIM" >/dev/null 2>&1 || true
fi

# Check if legacy skills directory exists and build warning
warning_message=""
legacy_skills_dir="${HOME}/.config/superpowers/skills"
if [ -d "$legacy_skills_dir" ]; then
    warning_message="\n\n<important-reminder>IN YOUR FIRST REPLY AFTER SEEING THIS MESSAGE YOU MUST TELL THE USER:⚠️ **WARNING:** Superpowers now uses Claude Code's skills system. Custom skills in ~/.config/superpowers/skills will not be read. Move custom skills to ~/.claude/skills instead. To make this message go away, remove ~/.config/superpowers/skills</important-reminder>"
fi

# Read using-superpowers content
using_superpowers_content=$(cat "${PLUGIN_ROOT}/skills/using-superpowers/SKILL.md" 2>&1 || echo "Error reading using-superpowers skill")

# Detect which backends are available
codex_status="not found"
gemini_status="not found"

if command -v codex &>/dev/null; then
    codex_version=$(codex --version 2>/dev/null || echo "unknown")
    codex_status="available (${codex_version})"
fi

if command -v gemini &>/dev/null; then
    gemini_version=$(gemini --version 2>/dev/null || echo "unknown")
    gemini_status="available (${gemini_version})"
fi

# Escape string for JSON embedding using bash parameter substitution.
escape_for_json() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

using_superpowers_escaped=$(escape_for_json "$using_superpowers_content")
warning_escaped=$(escape_for_json "$warning_message")

# Build routing context
routing_context="\\n\\n**Multi-Agent Routing Active (superpower-router plugin):**\\n"
routing_context+="- Codex CLI: ${codex_status}\\n"
routing_context+="- Gemini CLI: ${gemini_status}\\n"
routing_context+="- Fallback: Sonnet 4.6 (user-confirmed only when Codex fails)\\n\\n"
routing_context+="When dispatching subagent work, invoke superpower-router:plan-and-execute to route tasks to the cheapest capable backend instead of spawning Claude subagents.\\n"
routing_context+="Routing is the default behavior when tools are available. Do not execute Codex/Gemini-eligible work directly in Claude first.\\n"
routing_context+="- Code tasks (implement, review, refactor) → Codex CLI via codex-runner.sh\\n"
routing_context+="- Research tasks (web, docs, trends) → Gemini CLI via gemini-runner.sh\\n"
routing_context+="- Orchestration (plan, decide, synthesize) → Stay on Claude\\n"
routing_context+="- Codex failure (default fail-closed) → Ask user before Claude/Sonnet fallback"
routing_context+="\\n\\nRunner paths:\\n"
routing_context+="- Canonical Codex runner: ${CODEX_RUNNER}\\n"
routing_context+="- Canonical Gemini runner: ${GEMINI_RUNNER}\\n"
routing_context+="- Compatibility Codex runner: ${CLAUDE_CODEX_SHIM}\\n"
routing_context+="- Compatibility Gemini runner: ${CLAUDE_GEMINI_SHIM}\\n"
routing_context+="\\nRunner invocation examples (use /bin/bash explicitly):\\n"
routing_context+="- Codex code task: /bin/bash ${CLAUDE_CODEX_SHIM} \"<task prompt>\" workspace-write \"<working-dir>\"\\n"
routing_context+="- Codex review/read-only: /bin/bash ${CLAUDE_CODEX_SHIM} \"<task prompt>\" read-only \"<working-dir>\"\\n"
routing_context+="- Gemini research task: /bin/bash ${CLAUDE_GEMINI_SHIM} \"<research prompt>\""

routing_escaped=$(escape_for_json "$routing_context")

# Output context injection as JSON
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "<EXTREMELY_IMPORTANT>\nYou have superpowers with multi-agent routing.\n\n**Below is the full content of your 'superpower-router:using-superpowers' skill - your introduction to using skills. For all other skills, use the 'Skill' tool:**\n\n${using_superpowers_escaped}\n\n${routing_escaped}\n\n${warning_escaped}\n</EXTREMELY_IMPORTANT>"
  }
}
EOF

exit 0
