---
name: plan-and-execute
description: Use when creating implementation plans and executing tasks with proactive Codex/Gemini routing and fail-closed Codex behavior before Claude/Sonnet fallback
---

# Plan and Execute

## Mission
Create bite-sized implementation plans and proactively dispatch execution to the cheapest capable backend.

## Hard Rules
1. Route first. Do not self-implement Codex-eligible tasks before trying Codex.
2. Route external research first. Do not do Gemini-eligible research in Claude by default.
3. Keep architecture and product decisions in Claude.
4. Codex is fail-closed by default. On Codex failure, ask the user for explicit approval before Claude/Sonnet fallback.
5. Verify outputs before handoff.

## 1) Backend Readiness Check
Before execution, check availability:

```bash
command -v codex >/dev/null && echo "codex:ok" || echo "codex:missing"
command -v gemini >/dev/null && echo "gemini:ok" || echo "gemini:missing"
```

If Codex is missing for code tasks, stop and ask the user whether to proceed on Claude/Sonnet fallback.  
If both backends are missing, report routing unavailability and ask before fallback.

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
| Work Type | Backend | Invocation |
|---|---|---|
| Implementation/refactor/tests | Codex CLI | `${CLAUDE_PLUGIN_ROOT}/skills/plan-and-execute/codex-runner.sh "[prompt]" workspace-write /path/to/project` |
| Code review/spec review | Codex CLI | `${CLAUDE_PLUGIN_ROOT}/skills/plan-and-execute/codex-runner.sh "[prompt]" read-only /path/to/project` |
| Web/docs/external research | Gemini CLI | `${CLAUDE_PLUGIN_ROOT}/skills/plan-and-execute/gemini-runner.sh "[prompt]"` |
| Independent option gathering (compare model outputs) | Codex + Gemini in parallel | `${CLAUDE_PLUGIN_ROOT}/skills/plan-and-execute/parallel-runner.sh "[shared prompt]" /path/to/project read-only` |
| Orchestration/synthesis | Claude | Stay on Claude |
| Fallback | Sonnet 4.6 | `Task(prompt, model:sonnet)` only after explicit user confirmation when Codex fails |

## 4) Prompt Contract for Routed Tasks
For every routed task prompt, include:
1. Goal and acceptance criteria
2. File paths and constraints
3. Required commands/tests
4. Expected output format (patch, summary, citations, etc.)

## 5) Execution Loop
1. Load the plan.
2. Execute in batches of up to 3 independent tasks.
3. For independent option/research tasks, run Codex + Gemini concurrently with `parallel-runner.sh`.
4. For all other tasks, dispatch to mapped backend first.
5. Handle exit codes per fallback policy.
6. Review and verify outputs between batches.
7. Continue until all tasks are complete.

## 6) Codex CLI Usage
| Item | Value |
|---|---|
| Model | `gpt-5.3-codex` |
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

## 7) Gemini CLI Usage
| Rule | Value |
|---|---|
| Prompt | Positional prompt argument |
| Output | `--output-format text` |
| Purpose | Search-grounded external research |

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/plan-and-execute/gemini-runner.sh" \
  "$PROMPT"
```

## 8) Parallel Multi-Model Option Mode
Use this when you want diverse options from both models for the same objective.

```bash
/bin/bash "${CLAUDE_PLUGIN_ROOT}/skills/plan-and-execute/parallel-runner.sh" \
  "$PROMPT" \
  /path/to/project \
  read-only
```

Advanced form with different prompts:

```bash
/bin/bash "${CLAUDE_PLUGIN_ROOT}/skills/plan-and-execute/parallel-runner.sh" \
  --codex-prompt "Analyze implementation trade-offs in this repository." \
  --gemini-prompt "Research latest external best practices and cite sources." \
  --workdir /path/to/project \
  --codex-sandbox read-only
```

## 9) Fallback and Error Handling
| Exit Code | Action |
|---|---|
| `0` | Success |
| `20` | Fail-closed signal. Ask user for explicit approval before Claude/Sonnet fallback. |
| `10`, `11`, `12`, `13`, `1` | Only if `CODEX_FAIL_CLOSED=0`: allow fallback/report per policy. |

## 10) Environment Defaults
| Variable | Default |
|---|---|
| `CODEX_MODEL` | `gpt-5.3-codex` |
| `CODEX_EFFORT` | `xhigh` |
| `CODEX_TIMEOUT` | `120` |
| `CODEX_FAIL_CLOSED` | `1` |
| `GEMINI_TIMEOUT` | `60` |

## 11) Anti-Patterns
- Creating a plan without a backend route per task
- Implementing code directly in Claude when Codex is available
- Doing external research directly in Claude when Gemini is available
- Skipping `parallel-runner.sh` for independent option-gathering tasks
- Skipping verification between batches
- Falling back without first attempting the mapped backend
- Proceeding on Claude/Sonnet after Codex failure without explicit user approval
