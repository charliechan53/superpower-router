---
description: Create and/or execute plans with explicit dual-model Codex routing (gpt-5.3-codex for code, gpt-5.4 for analysis)
---

Use the `plan-and-execute` skill directly by loading `skills/plan-and-execute/SKILL.md` and following it exactly.

Mandatory behavior for this command:
1. Run backend readiness check before any task dispatch:
   - `command -v codex >/dev/null && echo "codex:ok" || echo "codex:missing"`
2. Route repository exploration, implementation, refactor, tests, and code review to Codex CLI (gpt-5.3-codex):
   - `CODEX_MODEL=gpt-5.3-codex /bin/bash ~/.claude/codex-runner.sh "<prompt>" workspace-write "<working-dir>"`
   - `CODEX_MODEL=gpt-5.3-codex /bin/bash ~/.claude/codex-runner.sh "<prompt>" read-only "<working-dir>"`
3. Route logic review, analysis, and reasoning tasks to Codex CLI (gpt-5.4):
   - `/bin/bash ~/.claude/codex-runner.sh "<prompt>" read-only "<working-dir>"`
4. Route live web/docs research to Claude native tools (WebSearch/WebFetch); stay on Claude.
5. Use Claude only for orchestration, synthesis, and live web research.
6. Do not use Claude-native `Explore` or `Task` subagents for work eligible for Codex before attempting the mapped runner.
7. If Codex returns exit code `20`, stop and ask the user for explicit approval before any Claude/Sonnet fallback.
8. If no plan exists, create one at `docs/plans/YYYY-MM-DD-feature.md`, then execute in batches of up to 3 independent tasks.
