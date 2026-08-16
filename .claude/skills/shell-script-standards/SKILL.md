---
name: shell-script-standards
description: Use when writing or changing any shell script in this repo - the conventions and how to check them
---

# Shell Script Standards

47 tracked shell files: 43 `*.sh` plus four extensionless shebang scripts (`hooks/session-start` and
three under `skills/subagent-driven-development/scripts/`).

## Conventions

- `#!/usr/bin/env bash` and `set -euo pipefail`, unless the script is deliberately POSIX `sh`.
- Resolve paths from `${BASH_SOURCE[0]}`, never from `$PWD`:
  `REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"`. Hooks and scripts run with an
  uncontrolled working directory.
- Quote every expansion.
- ShellCheck clean at `--severity=warning`. Fix findings; do not blanket-disable. A single-rule,
  single-line `# shellcheck disable=SCxxxx` with a reason is acceptable.
- Format with `shfmt -i 2 -ci -bn`.

## Dependencies

`hooks/`, `scripts/`, and `skills/` are **shipped plugin code and must have zero external
dependencies** — POSIX shell only, no `jq`, no node.

`.claude/hooks/` and `tests/` are local tooling and may use `jq`. When they do, they must degrade
gracefully if it is missing rather than failing in a way that blocks work.

## Checking

```bash
./scripts/lint-shell.sh                 # changed files (default)
./scripts/lint-shell.sh --format        # shfmt -w, then lint
./scripts/lint-shell.sh --strict        # extra optional rules
./scripts/lint-shell.sh path/to/one.sh
```

Needs `shellcheck` on PATH (and `shfmt` for `--format`); the script exits 1 if either is missing.

**Do not use `--all` as a gate.** It fails on eleven pre-existing warnings in `tests/claude-code/`
(SC2155, SC2064, SC2320, SC2088) that predate these standards. Lint what you touched.

If the `lint-shell-on-edit` hook is registered, ShellCheck runs automatically on every shell file you
edit and feeds failures straight back to you.
