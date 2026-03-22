---
description: Execute plan with proactive dual-model Codex dispatch (gpt-5.3-codex for code, gpt-5.4 for analysis) and fallback controls
---

Use the `plan-and-execute` skill directly by loading `skills/plan-and-execute/SKILL.md`, then execute immediately.

During execution:
- Implementation/refactor/review tasks => Codex CLI (gpt-5.3-codex) first
- Logic review / analysis / reasoning tasks => Codex CLI (gpt-5.4) first
- Live web/docs research => Claude native WebSearch/WebFetch
- Independent option gathering => run two Codex invocations concurrently (one per model)
- If Codex fails, ask user before Claude/Sonnet fallback

Execution requirements:
1. Load the plan and execute in batches of up to 3 tasks.
2. Dispatch each task to the mapped backend before doing work yourself.
3. Codex (gpt-5.3-codex) first for code work. Codex (gpt-5.4) first for analysis/reasoning.
4. For routed tasks, invoke runner scripts explicitly:
   - `CODEX_MODEL=gpt-5.3-codex /bin/bash ~/.claude/codex-runner.sh "<prompt>" workspace-write "<working-dir>"`
   - `CODEX_MODEL=gpt-5.3-codex /bin/bash ~/.claude/codex-runner.sh "<prompt>" read-only "<working-dir>"`
   - `/bin/bash ~/.claude/codex-runner.sh "<prompt>" read-only "<working-dir>"` (gpt-5.4 default for analysis)
5. Do not use Claude-native `Explore` or `Task` subagents for Codex-eligible tasks before attempting the mapped runner.
6. If Codex fails, stop and ask the user for explicit approval before Claude/Sonnet fallback.
7. Review backend output between batches and continue.
