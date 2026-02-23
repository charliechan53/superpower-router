---
description: Execute plan with proactive Codex/Gemini dispatch and fallback controls
---

Use the `plan-and-execute` skill directly by loading `skills/plan-and-execute/SKILL.md`, then execute immediately.

During execution:
- Implementation/refactor/review tasks => Codex CLI first
- External research/docs => Gemini CLI first
- Independent option gathering => run Codex + Gemini concurrently via `parallel-runner.sh`
- If Codex fails, ask user before Claude/Sonnet fallback

Execution requirements:
1. Load the plan and execute in batches of up to 3 tasks.
2. Dispatch each task to the mapped backend before doing work yourself.
3. Codex first for code work. Gemini first for external research.
4. For routed tasks, invoke runner scripts explicitly:
   - `/bin/bash ~/.claude/codex-runner.sh "<prompt>" workspace-write "<working-dir>"`
   - `/bin/bash ~/.claude/codex-runner.sh "<prompt>" read-only "<working-dir>"`
   - `/bin/bash ~/.claude/gemini-runner.sh "<prompt>"`
   - `/bin/bash ~/.claude/parallel-runner.sh "<shared prompt>" "<working-dir>" read-only`
5. Do not use Claude-native `Explore` or `Task` subagents for Codex/Gemini-eligible tasks before attempting the mapped runner.
6. If Codex fails, stop and ask the user for explicit approval before Claude/Sonnet fallback.
7. Review backend output between batches and continue.
