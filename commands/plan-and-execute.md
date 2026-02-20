---
description: Alias command to create/execute plans with proactive Codex and Gemini routing
---

Invoke `superpower-router:plan-and-execute` and follow it exactly.

If no plan exists, create one first, then execute immediately in 3-task batches:
- Implementation/refactor/review: Codex CLI first
- Web/docs/external research: Gemini CLI first
- Orchestration and final synthesis: Claude
- Fallback to Sonnet only when runner exit codes require it
