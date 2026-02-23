---
description: Create an implementation plan with explicit backend routing per task
---

Use the `plan-and-execute` skill directly by loading `skills/plan-and-execute/SKILL.md`.

This command is plan-only unless the user explicitly asks to execute.

Planning requirements:
1. Save the plan in `docs/plans/YYYY-MM-DD-feature.md`.
2. Keep tasks 2-5 minutes each and include concrete file paths, commands, routed backend, and done criteria.
3. Add a routing decision and exact runner command per task:
   - Codex CLI for repository exploration, implementation, refactor, tests, and review.
   - Gemini CLI for web/docs/external research.
   - Claude only for orchestration/synthesis.
4. Include at least one Codex read-only exploration step for code-heavy tasks:
   - `/bin/bash ~/.claude/codex-runner.sh "<exploration prompt>" read-only "<working-dir>"`
5. Do not use Claude-native `Explore` or `Task` subagents for Codex/Gemini-eligible work while writing the plan.
6. If Codex returns exit code `20` during any routed preflight step, stop and ask the user before Claude/Sonnet fallback.
