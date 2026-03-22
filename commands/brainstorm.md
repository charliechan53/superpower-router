---
description: "Design-first flow. For brainstorming/analysis work, use Codex (gpt-5.4) for research; after approval hand off to plan-and-execute for Codex (gpt-5.3-codex) implementation."
---

Use the `brainstorming` skill directly by loading `skills/brainstorming/SKILL.md` and following it exactly.

Non-optional handoff after design approval:
1. Switch to the `plan-and-execute` skill by loading `skills/plan-and-execute/SKILL.md`.
2. For brainstorming/design context and analysis/research, route Codex (gpt-5.4) first.
3. After plan approval, route implementation/refactor/review tasks to Codex (gpt-5.3-codex).
4. If Codex fails, ask the user for explicit approval before Claude/Sonnet fallback.
