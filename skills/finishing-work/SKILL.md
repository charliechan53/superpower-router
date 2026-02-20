---
name: finishing-work
description: Use when implementation is complete and you need to verify work and decide how to integrate — covers verification-before-completion and branch finishing
---

# Finishing Work

## Overview

Verify work is actually done, then present integration options. Combines verification-before-completion and finishing-a-development-branch.

## Verification (MANDATORY before claiming done)

**Evidence before assertions. Always.**

| Check | Command | Must Pass |
|-------|---------|-----------|
| Tests pass | Run project test suite | All green |
| Linting clean | Run project linter | No errors |
| Build succeeds | Run project build | No errors |
| Changes committed | `git status` | Clean working tree |

**Run these commands and confirm output.** Do NOT claim "tests pass" without actually running them.

### Red Flags — STOP

- "I'm confident it works" without running tests
- "Tests should pass" without evidence
- "I verified manually" without command output
- Claiming done with uncommitted changes

## Integration Options

After verification passes, present these options:

| Option | When | Command |
|--------|------|---------|
| **Merge to main** | Simple feature, sole developer | `git checkout main && git merge [branch]` |
| **Create PR** | Team project, needs review | `gh pr create --title "..." --body "..."` |
| **Keep branch** | Not ready to integrate yet | Just inform user |
| **Squash merge** | Many small commits to clean up | `git checkout main && git merge --squash [branch]` |

### PR Format

```bash
gh pr create --title "short title" --body "$(cat <<'PREOF'
## Summary
- [bullet points]

## Test plan
- [ ] Tests pass
- [ ] Manual verification done
PREOF
)"
```

## Process

1. Run all verification checks
2. Show output to user
3. If all pass → present integration options
4. If any fail → fix first, re-verify
5. Execute user's choice
6. Confirm completion
