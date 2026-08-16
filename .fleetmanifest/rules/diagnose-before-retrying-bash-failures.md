---
slug: diagnose-before-retrying-bash-failures
tier: prose
defectClass: null
provenance: proposed
---

When a Bash command fails, do not immediately retry the same or a near-identical command. After one retry at most, stop and read the actual error output before trying again. If the failure repeats identically several times in a row, treat it as a persistent environment or hook issue (for example a missing prerequisite like jq, shellcheck, or shfmt breaking a .claude/hooks/ script) rather than a transient one, and switch to diagnosing root cause instead of looping.
