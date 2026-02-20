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

- For executable code tasks, route to Codex CLI first via `plan-and-execute`.
- For external research/docs lookup tasks, route to Gemini CLI first via `plan-and-execute`.
- For independent option gathering, route to Codex + Gemini in parallel via `plan-and-execute`.
- Codex is fail-closed by default for code tasks: if Codex fails, ask the user for explicit approval before proceeding on Claude/Sonnet fallback.

## Available Skills

| Skill | When to use |
|-------|------------|
| `brainstorming` | Before any creative/feature work |
| `test-driven-development` | Before writing implementation code |
| `systematic-debugging` | When hitting bugs or unexpected behavior |
| `plan-and-execute` | Writing plans, executing tasks, routing to Codex/Gemini |
| `code-review` | After implementation, or when receiving feedback |
| `finishing-work` | When claiming work is complete |
| `writing-skills` | Creating or editing skills |

## Skill Types

**Rigid** (TDD, debugging): Follow exactly.
**Flexible** (patterns): Adapt to context.
