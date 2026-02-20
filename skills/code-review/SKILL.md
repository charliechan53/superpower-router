---
name: code-review
description: Use when completing tasks, requesting review, or receiving code review feedback — covers both requesting and responding to reviews with technical rigor
---

# Code Review

## Overview

Covers both sides of code review: requesting reviews (dispatching reviewer subagents) and receiving feedback (verifying before implementing suggestions).

## Requesting Review

After completing implementation, dispatch two reviews in order:

### 1. Spec Compliance Review

Route to Codex CLI (read-only):
```bash
${CLAUDE_PLUGIN_ROOT}/skills/plan-and-execute/codex-runner.sh \
  "Review code for spec compliance. Spec: [requirements]. Files: [paths]. Report: APPROVED or NEEDS CHANGES with specifics." \
  read-only /path/to/project
```

Fallback: `Task(prompt, model:"sonnet", subagent_type:"superpower-router:code-reviewer")`

### 2. Code Quality Review

Only after spec compliance passes. Route to Codex CLI (read-only):
```bash
${CLAUDE_PLUGIN_ROOT}/skills/plan-and-execute/codex-runner.sh \
  "Review code quality. Files: [paths]. Check: naming, error handling, DRY, YAGNI, test coverage. Report: Strengths, Issues (Critical/Important/Minor), APPROVED or NEEDS CHANGES." \
  read-only /path/to/project
```

### Review Loop

If reviewer finds issues → fix → re-review → repeat until approved.

## Receiving Review Feedback

When YOU receive feedback, apply technical rigor:

| Step | Action |
|------|--------|
| 1 | Read feedback carefully — don't skim |
| 2 | Verify each suggestion is technically correct before implementing |
| 3 | If suggestion seems wrong, research it (WebSearch, docs) before disagreeing |
| 4 | If genuinely wrong, explain why with evidence — don't just agree |
| 5 | Implement valid suggestions, explain rejections |

### Red Flags

- **Never** agree performatively — verify first
- **Never** implement suggestions blindly without understanding why
- **Never** skip re-review after fixing issues
- **Never** start quality review before spec compliance passes

## Reviewer Agent Prompt

See `./code-reviewer.md` for the detailed reviewer agent prompt template.
