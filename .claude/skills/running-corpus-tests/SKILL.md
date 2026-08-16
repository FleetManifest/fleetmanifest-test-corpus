---
name: running-corpus-tests
description: Use when running or choosing tests in this repo - which suite covers what, and which ones cost real tokens
---

# Running Corpus Tests

`tests/` holds non-LLM plugin tests. Skill *behaviour* evals live in the separate `superpowers-evals`
repo, cloned into a gitignored `evals/` that is **absent from this checkout** — do not try to run them.

## Pick the suite by what you changed

| Changed | Run |
|---|---|
| `.claude/hooks/*` | `./tests/claude-hooks/test-guard-fixtures.sh`, `./tests/claude-hooks/test-lint-shell-on-edit.sh` |
| `.gitignore` | `./tests/claude-hooks/test-gitignore-scope.sh` |
| Any shell script | `./scripts/lint-shell.sh <the files>` then `./tests/shell-lint/test-lint-shell.sh` |
| `hooks/session-start`, `hooks/*.json` | `./tests/hooks/test-session-start.sh` |
| Brainstorm server JS | `cd tests/brainstorm-server && npm test` |
| OpenCode plugin | `./tests/opencode/setup.sh` then `./tests/opencode/run-tests.sh` |
| Codex packaging or sync | `./tests/codex/test-package-codex-plugin.sh`, `./tests/codex-plugin-sync/test-sync-to-codex-plugin.sh` |
| Kimi manifest | `./tests/kimi/run-tests.sh` |
| Antigravity | `./tests/antigravity/run-tests.sh` |
| Pi extension | `node tests/pi/test-pi-extension.mjs` |
| `skills/systematic-debugging/` | `./tests/systematic-debugging/test-find-polluter.sh` |

## The expensive ones

`tests/claude-code/` and `tests/explicit-skill-requests/` drive the real `claude` CLI in headless
mode. They consume tokens and take minutes to tens of minutes.

**Do not run them as part of a general "run the tests" sweep.** Run them only when the change is to
skill content that they cover, and tell your human partner before you start.

## Prerequisites

`shellcheck` and `shfmt` for the lint suites; `node` and `npm` for `brainstorm-server/`;
`tests/opencode/setup.sh` before the OpenCode suite. There is no repo-wide test runner — invoke the
suite you need.

Note that `./scripts/lint-shell.sh --all` fails on eleven pre-existing warnings in
`tests/claude-code/`. Lint the files you changed instead.
