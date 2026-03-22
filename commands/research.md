---
description: Research-only mode. Route logic/reasoning to Codex (gpt-5.4); route live web research to Claude WebSearch.
---

Use the `plan-and-execute` skill directly by loading `skills/plan-and-execute/SKILL.md` in research-only mode.

Requirements:
1. For logic, reasoning, and analysis research: route to Codex CLI (gpt-5.4):
   - `/bin/bash ~/.claude/codex-runner.sh "<research prompt>" read-only "<working-dir>"`
2. For live web/docs research: use Claude's native `WebSearch`/`WebFetch` tools; stay on Claude.
3. Do not route to Codex with gpt-5.3-codex unless the user asks for implementation/code changes.
4. Return findings and sources succinctly.
5. If Codex fails, ask the user before Claude fallback.
