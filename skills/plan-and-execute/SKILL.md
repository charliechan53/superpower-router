---
name: plan-and-execute
description: Use when creating implementation plans and executing tasks with proactive routing to Codex CLI (code) and Gemini CLI (research), with Sonnet fallback
---

# Plan and Execute

## Mission
Create bite-sized implementation plans and proactively dispatch execution to the cheapest capable backend.

## Hard Rules
1. Route first. Do not self-implement Codex-eligible tasks before trying Codex.
2. Route external research first. Do not do Gemini-eligible research in Claude by default.
3. Keep architecture and product decisions in Claude.
4. Use Sonnet only as fallback when routing fails with approved fallback codes.
5. Verify outputs before handoff.

## 1) Backend Readiness Check
Before execution, check availability:

```bash
command -v codex >/dev/null && echo "codex:ok" || echo "codex:missing"
command -v gemini >/dev/null && echo "gemini:ok" || echo "gemini:missing"
```

If one backend is missing, continue with the other plus fallback.  
If both are missing, use Sonnet fallback and report routing unavailability.

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
| Orchestration/synthesis | Claude | Stay on Claude |
| Fallback | Sonnet 4.6 | `Task(prompt, model:sonnet)` |

## 4) Prompt Contract for Routed Tasks
For every routed task prompt, include:
1. Goal and acceptance criteria
2. File paths and constraints
3. Required commands/tests
4. Expected output format (patch, summary, citations, etc.)

## 5) Execution Loop
1. Load the plan.
2. Execute in batches of up to 3 independent tasks.
3. For each task, dispatch to mapped backend first.
4. Handle exit codes per fallback policy.
5. Review and verify outputs between batches.
6. Continue until all tasks are complete.

## 6) Codex CLI Usage
| Item | Value |
|---|---|
| Model | `gpt-5.3-codex` |
| Sandbox modes | `workspace-write`, `read-only` |
| Flags | `--full-auto --skip-git-repo-check` |

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

## 8) Fallback and Error Handling
| Exit Code | Action |
|---|---|
| `0` | Success |
| `10`, `12`, `1` | Retry task via Sonnet fallback |
| `11`, `13` | Report backend unavailable and continue with remaining routes/fallback |

## 9) Environment Defaults
| Variable | Default |
|---|---|
| `CODEX_MODEL` | `gpt-5.3-codex` |
| `CODEX_EFFORT` | `xhigh` |
| `CODEX_TIMEOUT` | `120` |
| `GEMINI_TIMEOUT` | `60` |

## 10) Anti-Patterns
- Creating a plan without a backend route per task
- Implementing code directly in Claude when Codex is available
- Doing external research directly in Claude when Gemini is available
- Skipping verification between batches
- Falling back without first attempting the mapped backend
