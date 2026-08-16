# scripts/

Maintenance and release tooling. These standards apply to **every** shell script in the repo —
`scripts/`, `hooks/`, `tests/`, and `.claude/hooks/`.

## Shell standards

- `#!/usr/bin/env bash` and `set -euo pipefail`, unless the script is deliberately POSIX `sh`.
- ShellCheck clean at `--severity=warning`. No blanket `# shellcheck disable` — fix the finding, or
  disable one rule on one line with a comment saying why.
- Format with `shfmt -i 2 -ci -bn` (2-space indent, indented switch cases, binary ops at line start).
- Resolve paths from `${BASH_SOURCE[0]}`, never from `$PWD`. Hooks and scripts run with an
  uncontrolled working directory.
- Quote every expansion. Paths in this repo and in `$HOME` contain spaces.

## Checking your work

```bash
./scripts/lint-shell.sh                 # changed files (default)
./scripts/lint-shell.sh --all           # every tracked shell file (42 of them)
./scripts/lint-shell.sh --format        # shfmt -w first, then lint
./scripts/lint-shell.sh --strict        # extra optional ShellCheck rules
./scripts/lint-shell.sh path/to/one.sh  # a specific file
```

Requires `shellcheck` on PATH, and `shfmt` for `--format`. The script `die`s if they are missing.

## The scripts

- `lint-shell.sh` — the linter above.
- `bump-version.sh` — version bump, driven by `.version-bump.json`.
- `sync-to-codex-plugin.sh` — pushes this checkout to an external fork and opens a PR. A release
  step. Read its header before running it; `-n` is a dry run.
- `package-codex-plugin.sh` — builds the Codex portal archive.
