---
name: using-superpowers
description: Use when starting any conversation — establishes skill usage rules and multi-agent routing
---

# Using Skills

**Rule:** Check for relevant skills BEFORE any response or action. Use the `Skill` tool to invoke them.

## Skill Priority

1. **Process skills first** (brainstorming, debugging) — determine HOW to approach
2. **Implementation skills second** (plan-and-execute, code-review) — guide execution

## Routing Default

- For code construction and review tasks, route to Codex CLI (`gpt-5.3-codex`) via `plan-and-execute`.
- For logic review, analysis, and research tasks, route to Codex CLI (`gpt-5.4`) via `plan-and-execute`.
- For live web/docs research, use Claude's native `WebSearch`/`WebFetch` tools; stay on Claude.
- For independent option gathering, run two Codex invocations in parallel (one with each model) via `plan-and-execute`.
- Codex is fail-closed by default for code tasks: if Codex fails, ask the user for explicit approval before proceeding on Claude/Sonnet fallback.

## Available Skills

| Skill | When to use |
|-------|------------|
| `brainstorming` | Before any creative/feature work |
| `test-driven-development` | Before writing implementation code |
| `systematic-debugging` | When hitting bugs or unexpected behavior |
| `plan-and-execute` | Writing plans, executing tasks, routing to Codex (`gpt-5.3-codex` / `gpt-5.4`) |
| `code-review` | After implementation, or when receiving feedback |
| `finishing-work` | When claiming work is complete |
| `writing-skills` | Creating or editing skills |

## Skill Types

**Rigid** (TDD, debugging): Follow exactly.
**Flexible** (patterns): Adapt to context.
