# hooks/

The **plugin's shipped hooks** — distinct from `.claude/hooks/`, which is this repo's own local
enforcement tooling.

- `hooks.json` registers them for Claude Code; `hooks-cursor.json` does the same for Cursor.
- Commands are written against `${CLAUDE_PLUGIN_ROOT}` and dispatched through `run-hook.cmd`, a
  polyglot batch/shell file that makes the same entry point work on Windows and POSIX. See
  `docs/windows/polyglot-hooks.md`.
- `session-start` is the bootstrap that loads `using-superpowers` at session start. It has no `.sh`
  extension but is a shell script, and `scripts/lint-shell.sh` picks it up by shebang.

## Zero dependencies

This is shipped plugin code. It may use only what a stock POSIX shell and the harness provide — no
`jq`, no node, no external binaries. A dependency here breaks installs on machines that lack it.

(This rule does **not** apply to `.claude/hooks/`, which is local fixture tooling and may use `jq`.)

Shell standards are in `scripts/CLAUDE.md` and apply here too.
