# superpower-router

All-in-one Claude Code plugin that combines the **superpowers** skill suite, **Codex CLI delegation**, and **multi-agent routing** to reduce Claude token usage while keeping development workflows fast and structured.

- Author: [charliechan53](https://github.com/charliechan53)
- Repository: https://github.com/charliechan53/superpower-router
- License: MIT

## What It Includes

1. Full superpowers skill set from `obra/superpowers` (brainstorming, TDD, debugging, code review, planning, and more).
2. Codex CLI skill for delegating implementation-heavy work to OpenAI Codex.
3. New multi-agent router that sends subagent work to:
   - **Codex CLI** for code-centric tasks
   - **Gemini CLI** for web research tasks
   - **Sonnet 4.6** as fallback

## Prerequisites

- Claude Code
- Codex CLI (authenticated): `codex login`
- Gemini CLI: `npm install -g @google/gemini-cli`

## Installation

### Option 1: Local plugin install

```bash
mkdir -p ~/.claude/plugins
git clone https://github.com/charliechan53/superpower-router ~/.claude/plugins/superpower-router
```

### Option 2: Claude Code Marketplace

Install `superpower-router` from the Claude Code plugin marketplace.

## Skills (8 consolidated)

| Skill | What it does |
|-------|-------------|
| `using-superpowers` | Entry point — teaches Claude how to find and use skills |
| `brainstorming` | Collaborative design before implementation |
| `test-driven-development` | TDD discipline: red-green-refactor |
| `systematic-debugging` | Root-cause analysis, defense-in-depth |
| `plan-and-execute` | Write plans + execute via Codex/Gemini/Sonnet routing |
| `code-review` | Request and receive reviews (routes to Codex) |
| `finishing-work` | Verify + integrate (merge, PR, squash) |
| `writing-skills` | Create new skills with TDD methodology |

## Slash Commands

Use plugin-scoped slash commands (Claude UI may also show unscoped aliases):
Note: the command namespace is `superpower-router:` (not `superpower:`).

| Slash command | Purpose |
| --- | --- |
| `superpower-router:brainstorm` | Start design-first flow before implementation |
| `superpower-router:brainstorming` | Alias of `brainstorm` |
| `superpower-router:write-plan` | Create a routed implementation plan |
| `superpower-router:execute-plan` | Execute an existing plan with routed batches |
| `superpower-router:plan-and-execute` | Alias for combined routed planning/execution flow |

## Routing Table

| Task Type | Routed To | Why |
| --- | --- | --- |
| Code implementation, refactors, tests, debugging in repo context | Codex CLI | Offloads high-token coding loops from Claude |
| Web research, docs lookup, external fact gathering | Gemini CLI | Keeps browsing/research outside Claude context window |
| Unsupported/failed route, general fallback | Sonnet 4.6 | Reliable catch-all when other routes are unavailable |

## Environment Variables

```bash
export CODEX_MODEL=gpt-5.3-codex
export CODEX_EFFORT=xhigh
export CODEX_TIMEOUT=120
export GEMINI_TIMEOUT=60
```

## How It Saves Tokens

- Delegates large code-generation and code-edit loops to Codex CLI.
- Routes research-heavy tasks to Gemini CLI instead of consuming Claude context.
- Uses Sonnet 4.6 fallback only when routing cannot use Codex or Gemini.
- Preserves Claude context for orchestration, decisions, and final synthesis.

## Credits

- **superpowers** by Jesse Vincent (`obra/superpowers`)
- **skill-codex** by `skills-directory`
