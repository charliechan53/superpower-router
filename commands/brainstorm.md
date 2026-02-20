---
description: "Design-first flow. For brainstorming work, prioritize Gemini first; after approval hand off to plan-and-execute for Codex implementation."
---

Immediately invoke `superpower-router:brainstorming` and follow it exactly.

Non-optional handoff after design approval:
1. Invoke `superpower-router:plan-and-execute`.
2. For brainstorming/design context and external research, route Gemini first.
3. After plan approval, route implementation/refactor/review tasks to Codex.
4. If Codex fails, ask the user for explicit approval before Claude/Sonnet fallback.
