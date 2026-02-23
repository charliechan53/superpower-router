---
description: Create and/or execute plans with explicit Codex/Gemini-first routing
---

Use the `plan-and-execute` skill directly by loading `skills/plan-and-execute/SKILL.md` and following it exactly.

Mandatory behavior for this command:
1. Run backend readiness checks before any task dispatch:
   - `command -v codex >/dev/null && echo "codex:ok" || echo "codex:missing"`
   - `command -v gemini >/dev/null && echo "gemini:ok" || echo "gemini:missing"`
2. Route repository exploration, implementation, refactor, tests, and review to Codex CLI first:
   - `/bin/bash ~/.claude/codex-runner.sh "<prompt>" workspace-write "<working-dir>"`
   - `/bin/bash ~/.claude/codex-runner.sh "<prompt>" read-only "<working-dir>"`
3. Route external web/docs research to Gemini CLI first:
   - `/bin/bash ~/.claude/gemini-runner.sh "<prompt>"`
4. Route independent option gathering to Codex + Gemini parallel runner:
   - `/bin/bash ~/.claude/parallel-runner.sh "<shared prompt>" "<working-dir>" read-only`
5. Use Claude only for orchestration and synthesis.
6. Do not use Claude-native `Explore` or `Task` subagents for work eligible for Codex/Gemini before attempting the mapped runner.
7. If Codex returns exit code `20`, stop and ask the user for explicit approval before any Claude/Sonnet fallback.
8. If no plan exists, create one at `docs/plans/YYYY-MM-DD-feature.md`, then execute in batches of up to 3 independent tasks.
