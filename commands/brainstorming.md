---
description: Alias of brainstorm command; Gemini-first during brainstorming, then Codex during implementation
---

Invoke `superpower-router:brainstorming` immediately and follow it exactly.

After user approves the design, invoke `superpower-router:plan-and-execute` and route:
- Brainstorming research/design tasks to Gemini first
- Implementation/refactor/review tasks to Codex after plan approval
- If Codex fails, ask user before Claude/Sonnet fallback
