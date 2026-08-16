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

A `PreToolUse` hook blocks edits to the existing files and creation of new ones here. If you believe
a change is genuinely needed, say so and let your human partner decide — do not work around the hook.

The one exception the hook allows is this file.
