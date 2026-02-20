---
description: Research-only mode. Prioritize Gemini CLI and avoid Codex unless user explicitly asks for implementation.
---

Invoke `superpower-router:plan-and-execute` in research-only mode.

Requirements:
1. Route the task to Gemini CLI first using `gemini-runner.sh`.
2. Do not route to Codex unless the user asks for implementation/code changes.
3. Return findings and sources succinctly.
4. If Gemini fails, ask the user before Claude fallback.
