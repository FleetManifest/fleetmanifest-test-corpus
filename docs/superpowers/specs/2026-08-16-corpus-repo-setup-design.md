# Corpus Repo Agent Setup Design

**Date:** 2026-08-16
**Status:** Approved (design), pending implementation

## Problem

This repository is `FleetManifest/fleetmanifest-test-corpus` — a fork of Superpowers that exists
as a **test fixture for the FleetManifest platform**. It carries 200 seeded change stubs in
`corpus-changes/`, 203 remote `corpus/pr-NNNN` branches, a CI workflow that deliberately fails on
any branch ending `-fail` (`.github/workflows/corpus-ci.yml`), and two intentionally vulnerable
scanner fixtures in `corpus-fixtures/`.

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
   `--severity=warning`, optional `shfmt -i 2 -ci -bn`, and per-file syntax checks across 38
   tracked shell scripts. No hook, no CI job, and no documentation invokes it.
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
  `.claude/settings.json`, so the setup is reproducible by hand.
- **Where the scoped rules live** — a pointer table to the six subfolder files.
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
| `tests/CLAUDE.md` | Layout is one directory per harness (`antigravity`, `claude-code`, `codex`, `codex-plugin-sync`, `explicit-skill-requests`, `hooks`, `kimi`, `opencode`, `pi`, `shell-lint`, `systematic-debugging`, `brainstorm-server`). Bash-first, with `.test.js`/`.mjs` under `brainstorm-server`. Which suites are safe to run locally. |
| `hooks/CLAUDE.md` | Hooks are registered through `hooks/hooks.json` with `${CLAUDE_PLUGIN_ROOT}` paths, dispatched via `run-hook.cmd` for Windows polyglot compatibility. Zero external dependencies. |
| `scripts/CLAUDE.md` | Shell standards: `set -euo pipefail`, ShellCheck clean at `--severity=warning`, `shfmt -i 2 -ci -bn`, POSIX-safe where the shebang says `sh`. |

### 3. Four project skills

Written to `.claude/skills/<name>/SKILL.md`, frontmatter matching the compiler's two-field shape.

| Skill | Covers |
|---|---|
| `seeding-a-corpus-pr` | The repo's signature procedure and the only one that is currently undocumented anywhere: branch `corpus/pr-NNNN`, `-fail` suffix to arm the CI failure, the matching `corpus-changes/corpus-pr-NNNN.md` stub and its `Derived from <sha>` line. |
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
```

`.claude/settings.json` stays ignored: it holds FleetManifest's capture hooks with absolute
machine paths (`/Users/glynrob/www/fleetmanifest/platform/packages/cli/bin/capture.js`), which
must not be committed. Registration is documented in root `CLAUDE.md` instead.

This also fixes defect 3 — `fmanifest apply`'s skill output becomes visible to git.

### 5. Two enforcement hooks

Scripts tracked under `.claude/hooks/`, registered by hand in the untracked
`.claude/settings.json`.

| Script | Event | Behaviour |
|---|---|---|
| `guard-fixtures.sh` | `PreToolUse`, matcher `Edit\|Write\|MultiEdit` | Reads the tool input path from stdin JSON. If it is under `corpus-fixtures/` or `corpus-changes/`, deny with an explanation of why the file is deliberate. Otherwise allow. |
| `lint-shell-on-edit.sh` | `PostToolUse`, matcher `Edit\|Write\|MultiEdit` | If the edited path is a shell file, run `scripts/lint-shell.sh <path>`. Non-zero exit feeds ShellCheck's output back to the agent. Exits 0 silently when ShellCheck is not on PATH, so the hook is advisory rather than a hard blocker on a machine without it. |

Both must be dependency-free bash consistent with the repo's own shell standards, and both must
pass `scripts/lint-shell.sh` themselves.

## Explicitly out of scope

- **Pre-commit and CI wiring.** Enforcement is at the agent layer by decision. The dead
  `.pre-commit-config.yaml` is documented, not deleted — removing it is a separate call.
- **Upstream contribution.** Nothing here is intended for `obra/superpowers`.
- **Touching the fixture itself.** No seeded branch, stub, or vulnerable file is modified.

## Verification

The design is satisfied when all of the following hold:

1. `git check-ignore -v .claude/skills/seeding-a-corpus-pr/SKILL.md` reports **no** match, and
   `git check-ignore -v .claude/settings.json` still reports a match.
2. `scripts/lint-shell.sh --all` passes with the two new hook scripts tracked.
3. A `Write` to `corpus-fixtures/vulnerable-server.js` is denied by the hook; a `Write` to a
   scratch path is not.
4. Editing a `.sh` file with a deliberate ShellCheck warning surfaces that warning to the agent.
5. Root `CLAUDE.md` contains no upstream-only instruction (no `dev` branch, no PR template, no
   rejection-rate framing) and ends without trailing marker content.
6. Each of the six scoped `CLAUDE.md` files and four `SKILL.md` files exists at the specified path,
   with skills carrying exactly `name` and `description` frontmatter.
