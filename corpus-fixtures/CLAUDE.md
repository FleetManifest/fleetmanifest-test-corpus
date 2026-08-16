# corpus-fixtures/

**The vulnerabilities in this directory are the point.**

`vulnerable-server.js` and `vulnerable_handler.py` exist so that security scanners have something
to find. They are inputs to a test, not a backlog.

## Do not

- Fix, patch, or harden them.
- Add input validation, sanitisation, or a defensive wrapper.
- Add a `SECURITY.md`, a README, or a comment disclaiming the vulnerability — anything that changes
  what a scanner reports on this directory defeats the fixture.
- Delete them, or move them out of the way.

A `PreToolUse` hook blocks edits to the existing files and creation of new ones here, whether you go
through an editing tool or a shell command. If you believe a change is genuinely needed, say so and
let your human partner decide — do not work around the hook.

This file is the one exception, and the exception holds for both routes: editing tools and shell
commands alike may write `corpus-fixtures/CLAUDE.md`. It does not extend to anything else in this
directory — copying this file over a fixture is still blocked.

The shell-command half of the guard reads command text, so it cannot see through a variable, a
`cd` into this directory, or a symlink. It is a speed bump, not a security boundary. The rule above
is what actually governs; the hook only makes casual violations inconvenient.
