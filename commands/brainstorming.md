---
description: Alias of brainstorm command; Gemini-first during brainstorming, then Codex during implementation
---

Use the `brainstorming` skill directly by loading `skills/brainstorming/SKILL.md` and following it exactly.

After user approves the design, switch to the `plan-and-execute` skill by loading `skills/plan-and-execute/SKILL.md`, then route:
- Brainstorming research/design tasks to Gemini first
- Implementation/refactor/review tasks to Codex after plan approval
- If Codex fails, ask user before Claude/Sonnet fallback
