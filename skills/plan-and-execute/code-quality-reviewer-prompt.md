# Code Quality Reviewer Prompt Template

Use this template when dispatching a code quality reviewer subagent.

**Purpose:** Verify implementation is well-built (clean, tested, maintainable)

**Only dispatch after spec compliance review passes.**

Build the review prompt by filling in the template from `$CLAUDE_PLUGIN_ROOT/skills/code-review/code-reviewer.md`:

- `WHAT_WAS_IMPLEMENTED`: [from implementer's report]
- `PLAN_OR_REQUIREMENTS`: Task N from [plan-file]
- `BASE_SHA`: [commit before task]
- `HEAD_SHA`: [current commit]
- `DESCRIPTION`: [task summary]

Then route to Codex CLI (read-only):

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/plan-and-execute/codex-runner.sh" \
  "[filled review prompt]" \
  read-only \
  /path/to/project
```

Fallback (exit 10, 12, 1): `Task(prompt, model:"sonnet", subagent_type:"superpower-router:code-reviewer")`

**Code reviewer returns:** Strengths, Issues (Critical/Important/Minor), Assessment
