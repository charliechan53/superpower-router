---
name: plan-and-execute
description: Use when creating implementation plans, executing tasks, or dispatching work to Codex CLI, Gemini CLI, or Claude subagents — consolidates planning, execution, and multi-agent routing
---

## 1) Overview
| Goal | Rule |
|---|---|
| Plan + execute | Build plans, then route each task to the cheapest backend. |

## 2) Planning Phase
| Item | Requirement |
|---|---|
| Plan file | Save as `docs/plans/YYYY-MM-DD-feature.md`. |
| Task size | Each task must be `2-5 min`. |
| Task detail | Include file paths, code edits, and commands. |
| Scope | Tasks must be bite-sized and executable. |

## 3) Routing Table
| Work type | Backend | Invocation |
|---|---|---|
| Implementation/refactoring | Codex CLI | `${CLAUDE_PLUGIN_ROOT}/skills/plan-and-execute/codex-runner.sh "[prompt]" workspace-write /path/to/project` |
| Code Review | Codex CLI | `${CLAUDE_PLUGIN_ROOT}/skills/plan-and-execute/codex-runner.sh "[prompt]" read-only /path/to/project` |
| Web Research | Gemini CLI | `${CLAUDE_PLUGIN_ROOT}/skills/plan-and-execute/gemini-runner.sh "[prompt]"` |
| Orchestration | Claude | Stay on Claude |
| Fallback | Sonnet 4.6 | `Task(prompt, model:sonnet)` |

## 4) Execution Phase
| Step | Action |
|---|---|
| Load | Read the plan file. |
| Batch | Group work into 3-task batches. |
| Route | Send each task via the routing table. |
| Review | Review results between batches. |

## 5) Codex CLI Usage
| Item | Value |
|---|---|
| Model | `gpt-5.3-codex` |
| Flags | `--full-auto --skip-git-repo-check` |
| Sandbox modes | `workspace-write`, `read-only` |

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/plan-and-execute/codex-runner.sh" \
  "$PROMPT" \
  workspace-write \
  /path/to/project

"${CLAUDE_PLUGIN_ROOT}/skills/plan-and-execute/codex-runner.sh" \
  "$PROMPT" \
  read-only \
  /path/to/project
```

## 6) Gemini CLI Usage
| Rule | Value |
|---|---|
| Prompt | Use positional prompt argument |
| Output | `--output-format text` |
| Purpose | Web research / Search grounding |

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/plan-and-execute/gemini-runner.sh" \
  "$PROMPT"
```

## 7) Fallback
| Exit code | Action |
|---|---|
| `0` | Success |
| `10`, `12`, `1` | Retry with `Task(prompt, model:sonnet)` |
| `11`, `13` | Report failure to user |

## 8) Environment Variables
| Variable | Value |
|---|---|
| `CODEX_MODEL` | `gpt-5.3-codex` |
| `CODEX_EFFORT` | `xhigh` |
| `CODEX_TIMEOUT` | `120` |
| `GEMINI_TIMEOUT` | `60` |

## 9) Parallel Dispatch
| Condition | Action |
|---|---|
| 2+ independent tasks | Dispatch in parallel via Bash or `Task` calls |

## 10) Red Flags
| Never | Always |
|---|---|
| Let Codex/Gemini choose architecture | Keep architecture decisions in Claude |
| Skip review | Review all backend output |
| Present unverified work | Verify before handoff |
