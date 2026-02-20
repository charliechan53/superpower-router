---
description: Execute plan with proactive Codex/Gemini dispatch and fallback controls
---

Invoke `superpower-router:plan-and-execute` and execute immediately.

Execution requirements:
1. Load the plan and execute in batches of up to 3 tasks.
2. Dispatch each task to the mapped backend before doing work yourself.
3. Codex first for code work. Gemini first for external research.
4. If Codex fails, stop and ask the user for explicit approval before Claude/Sonnet fallback.
5. Review backend output between batches and continue.
