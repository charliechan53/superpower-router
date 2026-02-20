---
description: Alias command to create/execute plans with proactive Codex and Gemini routing
---

Invoke `superpower-router:plan-and-execute` and follow it exactly.

If no plan exists, create one first, then execute immediately in 3-task batches:
- Implementation/refactor/review: Codex CLI first
- Web/docs/external research: Gemini CLI first
- Independent option gathering: run Codex + Gemini concurrently via `parallel-runner.sh`
- Orchestration and final synthesis: Claude
- If Codex fails, ask user for explicit approval before Claude/Sonnet fallback
