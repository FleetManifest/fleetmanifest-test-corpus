# fleetmanifest-test-corpus

## What this repo is

A fork of [Superpowers](https://github.com/obra/superpowers) that exists as a **test fixture for
the FleetManifest platform**. It is not the upstream project, nothing here is supported, and it
must not be installed from.

That means the usual instinct — find something broken, fix it — is often wrong here. Several things
are broken *on purpose*.

## Fixture invariants

Do not repair any of these:

| What | Why it is that way |
|---|---|
| `corpus-fixtures/*` | Deliberately vulnerable files that exist for security scanners to find. See `corpus-fixtures/CLAUDE.md`. |
| `corpus-changes/*` | 200 seeded stubs paired one-to-one with `origin/corpus/pr-NNNN` branches. See `corpus-changes/CLAUDE.md`. |
| `*-fail` branches and stubs | 67 pairs carry a `-fail` suffix. `.github/workflows/corpus-ci.yml` fails CI on them by design, producing a red-CI signal on demand. |

A `PreToolUse` hook blocks edits to the first two. If you think a change is genuinely needed, raise
it with your human partner rather than working around the hook.

## Local setup

The enforcement hooks live in `.claude/hooks/` (tracked). Their registration does not, because
`.claude/settings.json` also holds FleetManifest's capture hooks with absolute machine paths.

To enable them, merge `.claude/settings.example.json` into your `.claude/settings.json`, keeping any
`fleetmanifest`/`capture.js` entries already there — `fmanifest init` merges rather than overwrites,
so the two coexist. Both files define `PostToolUse`, so concatenate the arrays for that key rather
than letting one replace the other.

Prerequisites: `jq` (hook JSON parsing), `shellcheck` and `shfmt` (shell linting).

```bash
brew install jq shellcheck shfmt
```

Both hooks degrade rather than break when a tool is missing: the lint hook goes silent, and the
guard falls back to a coarser substring match that still protects the fixture directories.

## Where the rules live

| Scope | File |
|---|---|
| Seeded change stubs | `corpus-changes/CLAUDE.md` |
| Vulnerable scanner fixtures | `corpus-fixtures/CLAUDE.md` |
| Superpowers skill content | `skills/CLAUDE.md` |
| Test suites | `tests/CLAUDE.md` |
| Shipped plugin hooks | `hooks/CLAUDE.md` |
| Shell standards (all shell in the repo) | `scripts/CLAUDE.md` |

`.claude/hooks/` has no scoped file of its own; it follows `scripts/CLAUDE.md`.

Project skills for this repo's own procedures are in `.claude/skills/`: `seeding-a-corpus-pr`,
`running-corpus-tests`, `editing-a-superpowers-skill`, `shell-script-standards`.

## FleetManifest integration

`.fleetmanifest/config.yml` sets `compiler.targets: [claude-md, claude-skill]`. The compiler writes
to exactly two places:

- **This file**, as delimited blocks. Each block sits between a pair of HTML comments carrying
  `fleetmanifest:start slug=…` and `fleetmanifest:end slug=…`. Everything outside those markers is
  preserved byte-for-byte, and new blocks are appended at the end. Leave the tail of this file alone.

  **Never write a literal marker comment into this file as an example.** The compiler's parser is a
  regex over raw text — markdown backticks do not hide it. A start marker with no matching end is an
  `unterminated` error, and the compiler answers that by writing *nothing at all*, not by skipping
  the file. `tests/claude-hooks/test-claude-md-markers.sh` guards against this.
- **`.claude/skills/<slug>/SKILL.md`**, as whole files. A hand-written skill at a colliding slug
  will be taken over — reported as `adopted`, not silently.

`.gitignore` is narrowed so both paths are visible to git. Widening it back to a blanket `.claude/`
would make `fmanifest apply` produce an empty PR.

## Known dead configuration

Documented so nobody rediscovers them as bugs:

- **`.pre-commit-config.yaml` is a no-op.** All three hooks match `^evals/.*\.py$`, and `evals/` is
  both gitignored and absent from this checkout.
- **`scripts/lint-shell.sh --all` already fails.** Eleven ShellCheck warnings in `tests/claude-code/`
  predate this setup. Lint the files you touch, not the whole tree.
- **`AGENTS.md` is a symlink to this file.** Harmless today. If `agents-md` is ever added to
  `compiler.targets`, both targets would resolve to the same inode and the compiler would hit
  `duplicate-slug` and refuse to write anything at all.

## Contributing upstream

Don't, from here. This fork takes no external contributions and has no `dev` branch. Work intended
for `obra/superpowers` belongs in a checkout of that repo, under its own contributor guidelines.

<!-- fleetmanifest:start slug=diagnose-before-retrying-bash-failures tier=prose sha=0bc0751e -->
When a Bash command fails, do not immediately retry the same or a near-identical command. After one retry at most, stop and read the actual error output before trying again. If the failure repeats identically several times in a row, treat it as a persistent environment or hook issue (for example a missing prerequisite like jq, shellcheck, or shfmt breaking a .claude/hooks/ script) rather than a transient one, and switch to diagnosing root cause instead of looping.
<!-- fleetmanifest:end slug=diagnose-before-retrying-bash-failures -->
