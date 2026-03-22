---
description: Alias of brainstorm command; Codex gpt-5.4 during brainstorming/analysis, Codex gpt-5.3-codex during implementation
---

Use the `brainstorming` skill directly by loading `skills/brainstorming/SKILL.md` and following it exactly.

After user approves the design, switch to the `plan-and-execute` skill by loading `skills/plan-and-execute/SKILL.md`, then route:
- Brainstorming research/design tasks to Codex (gpt-5.4) first
- Implementation/refactor/review tasks to Codex (gpt-5.3-codex) after plan approval
- If Codex fails, ask user before Claude/Sonnet fallback
