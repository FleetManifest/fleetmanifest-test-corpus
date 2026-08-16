# tests/

Non-LLM plugin tests: does the plugin's own code work? Skill *behaviour* evals are a separate
harness in the `superpowers-evals` repo, cloned into a gitignored `evals/` that is absent here.

## Layout

One directory per harness or subject. Bash-first — `.sh` throughout, plus:

- `brainstorm-server/` — 7 `.test.js` (the only JavaScript under `tests/`) and 3 `.test.sh`
- `opencode/test-bootstrap-caching.mjs` and `pi/test-pi-extension.mjs`
- `claude-code/analyze-token-usage.py` — a token-telemetry utility, not a test
- `claude-hooks/` — tests for the local enforcement hooks in `.claude/hooks/`

## Running

Each directory exposes its own entry point: `run-tests.sh`, `run-all.sh`, `run-skill-tests.sh`, or
`npm test` under `brainstorm-server/`.

All thirteen directories, classified — no suite is left for you to guess about:

**Cheap and safe locally:** `claude-hooks/`, `shell-lint/`, `codex/`, `codex-plugin-sync/`,
`kimi/`, `hooks/`, `brainstorm-server/`, `systematic-debugging/`, `antigravity/`, `pi/`, and
`opencode/` (which needs `setup.sh` first).

**Expensive — do not run casually:** `claude-code/` and `explicit-skill-requests/` drive the real
`claude` CLI in headless mode. They cost tokens and take minutes. Run them deliberately, not as
part of a general "run the tests" sweep, and say so before you do.

`systematic-debugging/test-find-polluter.sh` is the test for
`skills/systematic-debugging/`'s polluter-finding script — easy to miss, because the skill and its
test are the only pair here that live in different top-level directories.

## Writing a test

Follow the existing shape: `#!/usr/bin/env bash`, `set -euo pipefail`, a `SCRIPT_DIR`/`REPO_ROOT`
pair resolved from `${BASH_SOURCE[0]}`, `pass`/`fail` helpers incrementing a `FAILURES` counter,
`mktemp -d` with a `trap ... EXIT` cleanup, and a non-zero exit when `FAILURES` is non-zero.
`tests/hooks/test-session-start.sh` is the reference.
