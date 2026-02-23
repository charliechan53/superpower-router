---
description: "Design-first flow. For brainstorming work, prioritize Gemini first; after approval hand off to plan-and-execute for Codex implementation."
---

Use the `brainstorming` skill directly by loading `skills/brainstorming/SKILL.md` and following it exactly.

Non-optional handoff after design approval:
1. Switch to the `plan-and-execute` skill by loading `skills/plan-and-execute/SKILL.md`.
2. For brainstorming/design context and external research, route Gemini first.
3. After plan approval, route implementation/refactor/review tasks to Codex.
4. If Codex fails, ask the user for explicit approval before Claude/Sonnet fallback.
