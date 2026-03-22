---
name: plan-and-execute
description: Use when creating implementation plans and executing tasks with proactive dual-model Codex routing (gpt-5.3-codex for code, gpt-5.4 for analysis) and fail-closed behavior before Claude/Sonnet fallback
---

# Plan and Execute

## Mission
Create bite-sized implementation plans and proactively dispatch execution to the cheapest capable backend.

## Hard Rules
1. Route first. Do not self-implement Codex-eligible tasks before trying Codex.
2. Route repository exploration for code tasks to Codex (read-only) before using Claude-native Explore/Task subagents.
3. Route analysis/reasoning research to Codex (gpt-5.4). Use Claude WebSearch/WebFetch for live web research.
4. Keep architecture and product decisions in Claude.
5. Codex is fail-closed by default. On Codex failure, ask the user for explicit approval before Claude/Sonnet fallback.
6. Verify outputs before handoff.

## 1) Backend Readiness Check
Before execution, check availability:

```bash
command -v codex >/dev/null && echo "codex:ok" || echo "codex:missing"
```

If Codex is missing for code tasks, stop and ask the user whether to proceed on Claude/Sonnet fallback.

## 2) Planning Requirements
- Save plan as `docs/plans/YYYY-MM-DD-feature.md`.
- Keep tasks `2-5 min` each.
- Every task must include:
  - objective
  - concrete file paths
  - command(s)
  - routed backend
  - done criteria
- Add a routing summary table to the plan.

## 3) Routing Policy
| Work Type | Backend | Model | Invocation |
|---|---|---|---|
| Repository exploration / static codebase analysis | Codex CLI | `gpt-5.3-codex` | `CODEX_MODEL=gpt-5.3-codex ${CLAUDE_PLUGIN_ROOT}/skills/plan-and-execute/codex-runner.sh "[prompt]" read-only /path/to/project` |
| Implementation/refactor/tests | Codex CLI | `gpt-5.3-codex` | `CODEX_MODEL=gpt-5.3-codex ${CLAUDE_PLUGIN_ROOT}/skills/plan-and-execute/codex-runner.sh "[prompt]" workspace-write /path/to/project` |
| Code review/spec review | Codex CLI | `gpt-5.3-codex` | `CODEX_MODEL=gpt-5.3-codex ${CLAUDE_PLUGIN_ROOT}/skills/plan-and-execute/codex-runner.sh "[prompt]" read-only /path/to/project` |
| Logic review / analysis / non-code reasoning | Codex CLI | `gpt-5.4` | `${CLAUDE_PLUGIN_ROOT}/skills/plan-and-execute/codex-runner.sh "[prompt]" read-only /path/to/project` |
| Live web / docs / external research | Claude native | — | Use `WebSearch` / `WebFetch` tools; stay on Claude |
| Independent option gathering (compare model outputs) | Codex × 2 in parallel | both | Run two codex-runner.sh invocations concurrently — one with `CODEX_MODEL=gpt-5.3-codex`, one with default `gpt-5.4` |
| Orchestration/synthesis | Claude | — | Stay on Claude |
| Fallback | Sonnet 4.6 | — | `Task(prompt, model:sonnet)` only after explicit user confirmation when Codex fails |

## 4) Prompt Contract for Routed Tasks
For every routed task prompt, include:
1. Goal and acceptance criteria
2. File paths and constraints
3. Required commands/tests
4. Expected output format (patch, summary, citations, etc.)

## 5) Execution Loop
1. Load the plan.
2. Execute in batches of up to 3 independent tasks.
3. For independent option-gathering tasks, run two Codex invocations concurrently (one per model).
4. For all other tasks, dispatch to mapped backend with the correct `CODEX_MODEL` first.
5. Handle exit codes per fallback policy.
6. Review and verify outputs between batches.
7. Continue until all tasks are complete.

## 6) Codex CLI Usage
| Item | Value |
|---|---|
| Model (code tasks) | `gpt-5.3-codex` — set via `CODEX_MODEL=gpt-5.3-codex` |
| Model (logic/analysis/research tasks) | `gpt-5.4` (default) |
| Sandbox modes | `workspace-write`, `read-only` |
| Flags | `--full-auto --skip-git-repo-check` |

Accepted invocation formats:
- Standard: `codex-runner.sh "<prompt>" [sandbox-mode] [working-dir]`
- Legacy-compatible: `codex-runner.sh "<prompt>" <working-dir> [sandbox-mode]`
- Legacy default: if only `<working-dir>` is provided, sandbox defaults to `workspace-write`

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/plan-and-execute/codex-runner.sh" \
  "$PROMPT" \
  workspace-write \
  /path/to/project
```

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/plan-and-execute/codex-runner.sh" \
  "$PROMPT" \
  read-only \
  /path/to/project
```

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/plan-and-execute/codex-runner.sh" \
  "$PROMPT" \
  /path/to/project

"${CLAUDE_PLUGIN_ROOT}/skills/plan-and-execute/codex-runner.sh" \
  "$PROMPT" \
  /path/to/project \
  read-only
```

## 7) Parallel Dual-Model Option Mode
Use this when you want diverse analysis from both Codex models for the same objective. Run two codex-runner.sh invocations concurrently in the background.

```bash
# Run gpt-5.3-codex (code perspective) in background
CODEX_MODEL=gpt-5.3-codex /bin/bash "${CLAUDE_PLUGIN_ROOT}/skills/plan-and-execute/codex-runner.sh" \
  "$PROMPT" read-only /path/to/project &
CODEX_PID_1=$!

# Run gpt-5.4 (logic/analysis perspective) in background
/bin/bash "${CLAUDE_PLUGIN_ROOT}/skills/plan-and-execute/codex-runner.sh" \
  "$PROMPT" read-only /path/to/project &
CODEX_PID_2=$!

wait $CODEX_PID_1; wait $CODEX_PID_2
```

## 9) Fallback and Error Handling
| Exit Code | Action |
|---|---|
| `0` | Success |
| `20` | Fail-closed signal. Ask user for explicit approval before Claude/Sonnet fallback. |
| `10`, `11`, `12`, `13`, `1` | Only if `CODEX_FAIL_CLOSED=0`: allow fallback/report per policy. |

## 10) Environment Defaults
| Variable | Default | Purpose |
|---|---|---|
| `CODEX_MODEL` | `gpt-5.4` | Override per-invocation; use `gpt-5.3-codex` for code tasks |
| `CODEX_MODEL_CODE` | `gpt-5.3-codex` | Reference value for code construction/review tasks |
| `CODEX_MODEL_LOGIC` | `gpt-5.4` | Reference value for logic review/analysis/research tasks |
| `CODEX_EFFORT` | `xhigh` | Reasoning effort |
| `CODEX_TIMEOUT` | `600` | Timeout in seconds |
| `CODEX_FAIL_CLOSED` | `1` | Stop and ask user before Claude fallback on failure |

Telemetry note:
- Router metrics track token offload plus backend attempt/success/failure health.
- Statusline format: `Offload C:<tokens> Σ:<tokens> | S/F C:<s>/<f> | RL C:<remaining>%@<reset-time>`.

## 11) Anti-Patterns
- Creating a plan without a backend route per task
- Using Claude-native `Explore`/`Task` subagents for Codex-eligible work before attempting routed runners
- Implementing code directly in Claude when Codex is available
- Using Claude for logic/analysis tasks when Codex (gpt-5.4) is available
- Skipping parallel dual-model invocation for independent option-gathering tasks
- Skipping verification between batches
- Falling back without first attempting the mapped backend
- Proceeding on Claude/Sonnet after Codex failure without explicit user approval
