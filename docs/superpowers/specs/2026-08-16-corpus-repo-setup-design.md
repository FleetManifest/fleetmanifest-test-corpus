# Corpus Repo Agent Setup Design

**Date:** 2026-08-16
**Status:** Approved (design), pending implementation

## Problem

This repository is `FleetManifest/fleetmanifest-test-corpus` — a fork of Superpowers that exists
as a **test fixture for the FleetManifest platform**. It carries 200 seeded change stubs in
`corpus-changes/` paired one-to-one with 200 remote `corpus/pr-NNNN` branches, of which 67 carry a
`-fail` suffix on both the branch and the stub filename to arm the CI workflow that deliberately
fails on them (`.github/workflows/corpus-ci.yml`), and two intentionally vulnerable scanner
fixtures in `corpus-fixtures/`.

None of that is written down anywhere an agent will read it. The consequences are concrete:

1. **Root `CLAUDE.md` describes a different repository.** All 8.8KB of it is upstream's
   contributor guide for `obra/superpowers` — a 94% PR rejection rate, a PR template to fill in,
   a rule that all PRs must target `dev`. This fork has no `dev` branch and takes no external
   contributions. An agent reading it is being instructed about the wrong project.
2. **Nothing warns an agent off the fixtures.** `corpus-fixtures/vulnerable-server.js` and
   `corpus-fixtures/vulnerable_handler.py` exist to be found by scanners. An agent that "helpfully"
   fixes them destroys the signal they exist to produce. The same applies to the 200 seeded stubs
   in `corpus-changes/` and their paired branches.
3. **`.gitignore` ignores `.claude/`, which breaks FleetManifest's own output.** The compiler's
   `claude-skill` target writes to `.claude/skills/<slug>/SKILL.md`
   (`packages/compiler/src/targets.ts:118`). In this repo git cannot see those files, so a PR
   opened by `fmanifest apply` would arrive empty. This is a fixture-breaking defect, not a
   preference.
4. **The one linter that exists is wired to nothing.** `scripts/lint-shell.sh` runs ShellCheck at
   `--severity=warning`, optional `shfmt -i 2 -ci -bn`, and per-file syntax checks across the 42
   tracked shell files its own `is_shell_file` logic matches — 38 `*.sh` plus four extensionless
   shebang scripts (`hooks/session-start`, and three under
   `skills/subagent-driven-development/scripts/`). No hook, no CI job, and no documentation
   invokes it.
   `.pre-commit-config.yaml`'s three hooks all match `^evals/.*\.py$`, and `evals/` is both
   gitignored and absent from the checkout — so pre-commit is a no-op here.

## Goal

Make this repo produce **realistic, high-signal agent sessions** for FleetManifest to capture,
without an agent being able to casually wreck the fixture. Optimisation serves testing the
platform; genuine agent ergonomics are the means, not the end.

**Not upstreamed.** Every change here is fork-specific and deliberately out of scope for a PR to
`obra/superpowers`.

## Constraints from the FleetManifest compiler

These were verified by reading the platform source, and they bound what may be hand-written where.

| Behaviour | Consequence for this design | Source |
|---|---|---|
| `claude-md` target writes root `CLAUDE.md` only; `pathFor` ignores its slug argument | Subfolder `CLAUDE.md` files are invisible to the compiler. They serve Claude Code, not FleetManifest. | `packages/compiler/src/targets.ts:102-121` |
| `kind: 'block'` — content is fenced by `<!-- fleetmanifest:start slug=… -->` / `:end` markers, appended at the end of the file | Root `CLAUDE.md` can be rewritten freely. Bytes outside markers are re-emitted verbatim. | `packages/compiler/src/markers.ts:325-345`, `compile.ts:164-210` |
| `claude-skill` writes a **whole file** and never reads pre-existing bytes; a takeover is flagged `adopted` | A hand-written skill at a colliding slug will be overwritten. Slug choice matters. | `packages/compiler/src/compile.ts:55-68`, `packages/cli/src/rules/apply.ts:74-95` |
| Skill frontmatter is exactly `name` and `description` | Hand-written skills should match that shape so compiler-written and hand-written skills are indistinguishable in form. | `packages/compiler/src/targets.ts:86-95` |
| A rule has no path scope — `Rule` is `{ slug, tier, defectClassId, provenance, body }` | There is no way to express "this rule applies only under `tests/`" as a FleetManifest rule. | `packages/compiler/src/types.ts:5-11` |
| Skills inventory scans exactly `.claude/skills/*/SKILL.md`, one level deep | Project skills must live at that exact depth to be inventoried. | `packages/cli/src/inventory/skills.ts:67-68,134` |
| `mergeCaptureHooks` rewrites only entries matching the capture binary and preserves siblings | Our own hooks can safely coexist in `.claude/settings.json`; `fmanifest init` re-runs will not clobber them. | `packages/cli/src/init/settings.ts:96-133` |

Two further notes recorded but **not acted on**:

- `sync.ruleText: false` in `.fleetmanifest/config.yml` is unimplemented — `redactProposal`
  receives it and explicitly discards it (`packages/shared/src/redact-proposal.ts:141-142`). It
  has no bearing on this design.
- `AGENTS.md` is a symlink to `CLAUDE.md`. `compiler.targets` is currently
  `[claude-md, claude-skill]`, so only one target resolves to that inode. If `agents-md` is ever
  added, both targets write the same file and the compiler will hit `duplicate-slug` and refuse to
  write **anything** (`packages/compiler/src/compile.ts:174-182`). Documented as a hazard.

## Design

### 1. Rewrite root `CLAUDE.md`

Replace the upstream contributor guide with a short, fork-accurate file. Sections:

- **What this repo is** — a FleetManifest test fixture, not the upstream project, not installable.
- **Fixture invariants** — the seeded branches, the `-fail` CI convention, the vulnerable fixtures.
  Stated as things that must not be repaired.
- **Local setup** — how to register the enforcement hooks in the untracked
  `.claude/settings.json` by copying from the committed `.claude/settings.example.json`, and the
  local prerequisites those hooks need (`jq`, `shellcheck`, `shfmt`).
- **Where the scoped rules live** — a pointer table to the six subfolder files, plus a line
  stating that `.claude/hooks/` follows `scripts/CLAUDE.md`'s shell standards, since no scoped
  file covers it.
- **Known dead configuration** — the no-op `.pre-commit-config.yaml` and the `AGENTS.md` symlink
  hazard, so nobody rediscovers them as bugs.

The tail of the file is left clean; the compiler appends its blocks there.

### 2. Six scoped `CLAUDE.md` files

Claude Code reads directory-scoped `CLAUDE.md` when working under that directory. FleetManifest
does not — these exist purely to shape in-repo agent behaviour, which is what the capture hooks
then record.

| Path | Carries |
|---|---|
| `corpus-changes/CLAUDE.md` | 200 seeded stubs paired with `corpus/pr-NNNN` branches. Do not edit, renumber, or regenerate. The `Derived from <sha>` line is provenance, not a task. |
| `corpus-fixtures/CLAUDE.md` | The vulnerabilities are the point. Do not fix, do not add mitigations, do not add a security note that would change scanner output. |
| `skills/CLAUDE.md` | Frontmatter is exactly `name` + `description`. "Your human partner" is deliberate. No reformatting to Anthropic's published skill guidance. Behavioural changes need eval evidence. Changes sync to `.codex-plugin` via `scripts/sync-to-codex-plugin.sh`. |
| `tests/CLAUDE.md` | Layout is one directory per harness (`antigravity`, `claude-code`, `codex`, `codex-plugin-sync`, `explicit-skill-requests`, `hooks`, `kimi`, `opencode`, `pi`, `shell-lint`, `systematic-debugging`, `brainstorm-server`). Bash-first: `.sh` throughout, plus three `.test.sh` and seven `.test.js` under `brainstorm-server` (the only `.js` anywhere under `tests/`), one `.mjs` each under `opencode/` and `pi/`, and one `.py` analysis script under `claude-code/`. Which suites are safe to run locally. |
| `hooks/CLAUDE.md` | Plugin hooks, registered through `hooks/hooks.json` (and `hooks/hooks-cursor.json` for Cursor) with `${CLAUDE_PLUGIN_ROOT}` paths, dispatched via `run-hook.cmd` for Windows polyglot compatibility. Zero external dependencies — this is shipped plugin code, unlike `.claude/hooks/`. |
| `scripts/CLAUDE.md` | Shell standards: `set -euo pipefail`, ShellCheck clean at `--severity=warning`, `shfmt -i 2 -ci -bn`, POSIX-safe where the shebang says `sh`. |

### 3. Four project skills

Written to `.claude/skills/<name>/SKILL.md`, frontmatter matching the compiler's two-field shape.

| Skill | Covers |
|---|---|
| `seeding-a-corpus-pr` | The repo's signature procedure and the only one currently undocumented anywhere: branch `corpus/pr-NNNN`, matching stub `corpus-changes/corpus-pr-NNNN.md`, stub body of title line + `Derived from <sha>.` + `Corpus entry N.`. **The `-fail` suffix must appear on both the branch and the stub filename** (`corpus/pr-0000-fail` ↔ `corpus-pr-0000-fail.md`) — 67 of the 200 pairs carry it, and a mismatched pair produces a branch whose CI outcome disagrees with its stub. |
| `running-corpus-tests` | Which suite to run for a given change, what each needs installed, what is safe locally versus CI-only. |
| `editing-a-superpowers-skill` | The high bar for anything under `skills/`: what may change without evidence, what may not, and the `.codex-plugin` sync step. |
| `shell-script-standards` | Invoking `scripts/lint-shell.sh` (default changed-files, `--all`, `--format`, `--strict`) and the conventions it enforces. |

**Slug collision.** These four names are gerund phrases; FleetManifest rule slugs derive from
defect classes and are unlikely to collide. A collision is not silent — `apply` reports the path
as `adopted`. Accepted risk, no prefix.

### 4. `.gitignore`

Replace the blanket `.claude/` entry with:

```
.claude/*
!.claude/skills/
!.claude/hooks/
!.claude/settings.example.json
```

`.claude/settings.json` stays ignored: it holds FleetManifest's capture hooks with absolute
machine paths (`/Users/glynrob/www/fleetmanifest/platform/packages/cli/bin/capture.js`), which
must not be committed.

`.claude/settings.example.json` is committed in its place — a machine-path-free file containing
only the two enforcement hook registrations from §5, using repo-relative script paths. It is the
copy-paste source for local setup and the artifact a stale registration can be diffed against.
Nothing reads it automatically; root `CLAUDE.md` points at it.

The negation pattern was verified empirically in a throwaway repo: `.claude/*` excludes the
`skills` and `hooks` directories themselves, so re-including them does not hit git's
"cannot re-include a file whose parent directory is excluded" rule. `settings.json` remains
matched by `.claude/*`.

This also fixes defect 3 — `fmanifest apply`'s skill output becomes visible to git.

### 5. Two enforcement hooks

Scripts tracked under `.claude/hooks/`, committed with the executable bit set, registered by hand
in the untracked `.claude/settings.json` from the committed example file.

**The protection rule, stated once.** A path is *protected* when it sits under `corpus-fixtures/`
or `corpus-changes/`. Given a protected path:

1. If its basename is `CLAUDE.md` — **allow**. Without this carve-out the two scoped files lock
   themselves out the moment they are created and could never be corrected.
2. Else if the file **exists** on disk — **deny**. This is the core rule: no modifying or deleting
   a vulnerable fixture or a seeded stub. Existence is tested on disk at hook time, not inferred
   from the tool name.
3. Else (a new file) — **allow only under `corpus-changes/`**. Creation there is what
   `seeding-a-corpus-pr` needs. Creation under `corpus-fixtures/` is denied: a new
   `vulnerable-server.fixed.js` or `SECURITY.md` beside the fixtures could change what a scanner
   reports on that directory, which is the outcome the guard exists to prevent.

| Script | Event / matcher | Behaviour |
|---|---|---|
| `guard-fixtures.sh` | `PreToolUse`, matcher `Edit\|Write\|MultiEdit` | Extracts `tool_input.file_path` from the stdin JSON. Applies the protection rule. Denies via JSON on stdout: `hookSpecificOutput.permissionDecision: "deny"` with a `permissionDecisionReason` explaining that the file is a deliberate fixture. Otherwise emits nothing and exits 0. |
| `guard-fixtures.sh` | `PreToolUse`, matcher `Bash` | Extracts `tool_input.command`. Denies when the command references `corpus-fixtures/` or `corpus-changes/` **and** matches a mutating pattern (`rm`, `mv`, `sed -i`, `truncate`, `tee`, `>` redirect, `git checkout --`, `git restore`), or when it matches a wholesale-discard pattern that needs no path at all (`git reset --hard`, `git clean`, `git stash`). Same deny mechanism. |
| `lint-shell-on-edit.sh` | `PostToolUse`, matcher `Edit\|Write\|MultiEdit` | If `tool_input.file_path` is a shell file, run `lint-shell.sh <path>`. On failure, **exit 2** with ShellCheck's output on stderr — for `PostToolUse`, exit 2 is the only code that routes stderr back to the model; other non-zero codes surface to the user instead. |

**The Bash guard is heuristic and acknowledged as such.** It will occasionally deny a harmless
command that merely names a protected path, and a determined agent can evade it (variable
indirection, `cd` then a bare filename). It raises the cost of casual damage; it is not a security
boundary. The scoped `CLAUDE.md` files remain the primary deterrent.

**Dependencies.** These are local fixture tooling, not shipped plugin code, so the plugin's
zero-dependency rule does not apply to them. Both use `jq` to parse the hook's stdin JSON — pure-bash
JSON parsing is fragile against escaped paths, and getting the path wrong in a guard is worse than
requiring a tool. The two hooks diverge on what happens when `jq` is missing:

- `guard-fixtures.sh` **fails closed, but only within its own blast radius.** Without `jq` it cannot
  extract a path, so it falls back to a plain `grep` of the raw stdin payload for `corpus-fixtures/`
  or `corpus-changes/` and denies only on a hit, naming the missing dependency in the reason.
  A blanket deny would reject every `Edit`, `Write` and `Bash` call in the repo and brick it — the
  fallback must be scoped to the paths the guard is responsible for. Everything else is allowed
  through unchanged.
- `lint-shell-on-edit.sh` **fails open** — exits 0 silently. It also checks for `shellcheck` on PATH
  itself before invoking `scripts/lint-shell.sh`, because that script calls `require_tool shellcheck`
  and `die`s with exit 1, which would surface as noise to the user on every shell edit rather than
  as advisory feedback.

Neither script may assume its working directory. Both resolve the repo root from their own location
(`$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)`) and use absolute paths from there — hooks run
with an uncontrolled cwd, so a relative `scripts/lint-shell.sh` would silently do nothing.

`jq`, `shellcheck`, and `shfmt` are recorded as local prerequisites in root `CLAUDE.md`.

Both scripts follow `scripts/CLAUDE.md`'s standards (`set -euo pipefail`, ShellCheck clean at
`--severity=warning`, `shfmt -i 2 -ci -bn`) and must pass `scripts/lint-shell.sh` themselves. Root
`CLAUDE.md` states that `.claude/hooks/` follows those standards, since neither `hooks/CLAUDE.md`
(plugin hooks) nor `scripts/CLAUDE.md` (`scripts/`) scopes to it.

## Explicitly out of scope

- **Pre-commit and CI wiring.** Enforcement is at the agent layer by decision. The dead
  `.pre-commit-config.yaml` is documented, not deleted — removing it is a separate call.
- **Upstream contribution.** Nothing here is intended for `obra/superpowers`.
- **Touching the fixture itself.** No seeded branch, stub, or vulnerable file is modified.

## Verification

Prerequisites: `jq`, `shellcheck`, and `shfmt` on PATH. `jq` is already installed at `/usr/bin/jq`;
`shellcheck` and `shfmt` are not, so installing those two is step zero — criterion 2 cannot run
without ShellCheck.

The design is satisfied when all of the following hold:

1. `git check-ignore -v .claude/skills/seeding-a-corpus-pr/SKILL.md` reports **no** match;
   `git check-ignore -v .claude/hooks/guard-fixtures.sh` reports **no** match;
   `git check-ignore -v .claude/settings.example.json` reports **no** match; and
   `git check-ignore -v .claude/settings.json` still reports a match.
2. `scripts/lint-shell.sh` passes on every file this work adds (the two hook scripts and the three
   test scripts). **Not** `--all`: the repo's baseline is already dirty — eleven warnings in
   `tests/claude-code/` (SC2155, SC2064, SC2320, SC2088) predate this work, and fixing upstream lint
   debt is out of scope.
3. Both hook scripts are tracked mode `100755` (`git ls-files -s .claude/hooks/`).
4. Guard denies: a `Write` to the existing `corpus-fixtures/vulnerable-server.js`; a `Write` to an
   existing `corpus-changes/corpus-pr-0001.md`; creation of a new `corpus-fixtures/SECURITY.md`;
   a Bash `rm corpus-fixtures/vulnerable_handler.py`; a Bash `git reset --hard`.
5. Guard allows: creation of a new `corpus-changes/corpus-pr-0200.md`; a `Write` to
   `corpus-fixtures/CLAUDE.md` **after** it already exists; a `Write` to a scratch path; a Bash
   `ls corpus-fixtures/`.
6. Editing a `.sh` file carrying a deliberate ShellCheck warning surfaces that warning to the agent
   (hook exits 2 with the diagnostic on stderr).
7. With `jq` removed from PATH: the guard still denies a `Write` to
   `corpus-fixtures/vulnerable-server.js`, **and still allows** a `Write` to a scratch path — both
   halves must hold, or the fallback has bricked the repo rather than scoped itself. The lint hook
   exits 0.
8. Root `CLAUDE.md` contains no upstream-only instruction (no `dev` branch, no PR template, no
   rejection-rate framing) and ends without trailing marker content.
9. Each of the six scoped `CLAUDE.md` files and four `SKILL.md` files exists at the specified path,
   with skills carrying exactly `name` and `description` frontmatter.
10. Each skill's content is checked against the repo: the branch/stub naming in
    `seeding-a-corpus-pr` matches the existing 200 pairs, and the suite list in
    `running-corpus-tests` matches the directories actually under `tests/`.
