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
   - **Codex + Gemini in parallel** for independent option gathering
   - **Sonnet 4.6** as user-confirmed fallback when Codex fails

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
| `plan-and-execute` | Write plans + execute via Codex/Gemini routing with fail-closed Codex fallback confirmation |
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
| `superpower-router:research` | Gemini-first research-only flow (no coding unless asked) |

## Routing Troubleshooting

If you see Claude-native output like `Explore(...) Sonnet 4.6` for code planning/exploration tasks, routing likely was not followed.

Quick checks:

```bash
command -v codex >/dev/null && echo "codex:ok" || echo "codex:missing"
command -v gemini >/dev/null && echo "gemini:ok" || echo "gemini:missing"
/bin/bash ~/.claude/plugins/superpower-router/hooks/router-statusline.sh
```

Expected behavior for code tasks:
- Repository exploration + implementation work should hit Codex first via `~/.claude/codex-runner.sh`.
- Sonnet fallback should only happen after explicit user confirmation when Codex fails in fail-closed mode.

## Routing Table

| Task Type | Routed To | Why |
| --- | --- | --- |
| Code implementation, refactors, tests, debugging in repo context | Codex CLI | Offloads high-token coding loops from Claude |
| Web research, docs lookup, external fact gathering | Gemini CLI | Keeps browsing/research outside Claude context window |
| Independent option gathering / model comparison | Codex + Gemini parallel runner | Produces diverse options faster from two models in one pass |
| Codex failure for code tasks | User-confirmed Claude/Sonnet fallback | Fail-closed by default to keep Codex priority and avoid silent fallback |

## Environment Variables

```bash
export CODEX_MODEL=gpt-5.3-codex
export CODEX_EFFORT=xhigh
export CODEX_TIMEOUT=120
export CODEX_FAIL_CLOSED=1
export GEMINI_TIMEOUT=60
```

## Deferred Token Indicator (ccstatusline)

`superpower-router` now tracks per-session offload telemetry for Codex/Gemini and exposes a status command:

```bash
~/.claude/plugins/superpower-router/hooks/router-statusline.sh
```

It renders:

```text
Offload C:<codex> G:<gemini> Σ:<total> | S/F C:<success>/<failure> G:<success>/<failure> | RL C:<remaining> G:<remaining|retry>
```

Notes:
- `C/G/Σ` are deferred token totals.
- `S/F` are backend success/failure counts for routed attempts.
- `RL` is best-effort rate-limit state: Codex shows remaining percent (`@HH:MM` reset when available), Gemini shows retry hint (for example `~40s`) or `N/A`.

Configure it in ccstatusline as a **Custom Command** widget (command = script above).

Optional metric file override:

```bash
export ROUTER_METRICS_FILE=/tmp/superpower-router-metrics.json
```

Metrics reset at Claude SessionStart (startup/resume/clear/compact).

## Deferred Token Indicator (native statusLine)

If you prefer Claude native status line command:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/plugins/superpower-router/hooks/router-statusline.sh"
  }
}
```

## Runner Compatibility Paths

On `SessionStart`, the plugin now auto-creates compatibility symlinks:

```bash
~/.claude/codex-runner.sh
~/.claude/gemini-runner.sh
~/.claude/parallel-runner.sh
```

Both point to the currently installed plugin runners and are intended for tools/prompts
that call runner scripts from `~/.claude/*`.

Use `/bin/bash` when invoking from hooks/prompts:

```bash
/bin/bash ~/.claude/codex-runner.sh "Fix failing tests" workspace-write "/path/to/repo"
/bin/bash ~/.claude/codex-runner.sh "Review recent changes" read-only "/path/to/repo"
/bin/bash ~/.claude/gemini-runner.sh "Research latest SDK breaking changes"
/bin/bash ~/.claude/parallel-runner.sh "Propose 3 implementation options with trade-offs" "/path/to/repo" read-only
```

## How It Saves Tokens

- Delegates large code-generation and code-edit loops to Codex CLI.
- Routes research-heavy tasks to Gemini CLI instead of consuming Claude context.
- Uses fail-closed Codex routing by default: asks user before any Claude/Sonnet fallback.
- Preserves Claude context for orchestration, decisions, and final synthesis.

## Credits

- **superpowers** by Jesse Vincent (`obra/superpowers`)
- **skill-codex** by `skills-directory`
