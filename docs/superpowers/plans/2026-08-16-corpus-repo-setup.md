# Corpus Repo Agent Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `FleetManifest/fleetmanifest-test-corpus` describe itself accurately to coding agents, protect its seeded fixtures from casual damage, and unignore the paths FleetManifest's compiler writes to.

**Architecture:** Three independent layers. (1) Two dependency-tolerant bash hooks under `.claude/hooks/`, driven by Claude Code's `PreToolUse`/`PostToolUse` JSON protocol and covered by bash tests under `tests/claude-hooks/`. (2) Seven prose files — a rewritten root `CLAUDE.md` plus six directory-scoped ones — carrying the rules. (3) Four project skills under `.claude/skills/`. A `.gitignore` change makes layers 1 and 3 visible to git.

**Tech Stack:** bash (ShellCheck `--severity=warning`, `shfmt -i 2 -ci -bn`), `jq` for hook JSON parsing, Markdown.

**Spec:** `docs/superpowers/specs/2026-08-16-corpus-repo-setup-design.md`

---

## Prerequisites

`jq` is already at `/usr/bin/jq`. `shellcheck` and `shfmt` are **not installed** and Task 2 onward cannot be verified without them.

```bash
brew install shellcheck shfmt
shellcheck --version && shfmt --version
```

## File Structure

| Path | Status | Responsibility |
|---|---|---|
| `.gitignore` | Modify | Narrow `.claude/` to `.claude/*` + three negations |
| `.claude/hooks/guard-fixtures.sh` | Create | PreToolUse: apply the fixture protection rule to Edit/Write/MultiEdit paths and Bash commands |
| `.claude/hooks/lint-shell-on-edit.sh` | Create | PostToolUse: ShellCheck an edited shell file, exit 2 with diagnostics |
| `.claude/settings.example.json` | Create | Machine-path-free registration for both hooks; copy source for local setup |
| `tests/claude-hooks/test-guard-fixtures.sh` | Create | Behavioural tests for the guard, incl. the jq-missing fallback |
| `tests/claude-hooks/test-lint-shell-on-edit.sh` | Create | Behavioural tests for the lint hook |
| `tests/claude-hooks/test-gitignore-scope.sh` | Create | Asserts which `.claude/` paths are and are not ignored |
| `CLAUDE.md` | Replace | What this repo is; fixture invariants; local setup; pointers; known dead config |
| `corpus-changes/CLAUDE.md` | Create | Seeded stubs are immutable; new stubs are how you add one |
| `corpus-fixtures/CLAUDE.md` | Create | The vulnerabilities are the point |
| `skills/CLAUDE.md` | Create | Skill-authoring bar |
| `tests/CLAUDE.md` | Create | Test layout and what is safe to run locally |
| `hooks/CLAUDE.md` | Create | Plugin hook wiring, zero-dependency rule |
| `scripts/CLAUDE.md` | Create | Shell standards |
| `.claude/skills/seeding-a-corpus-pr/SKILL.md` | Create | The signature procedure |
| `.claude/skills/running-corpus-tests/SKILL.md` | Create | Which suite, what it costs |
| `.claude/skills/editing-a-superpowers-skill/SKILL.md` | Create | The high bar for `skills/` |
| `.claude/skills/shell-script-standards/SKILL.md` | Create | Using `scripts/lint-shell.sh` |

**Ordering constraint:** hooks are built and tested (Tasks 2–3) but registered in `.claude/settings.json` only in Task 9, after every file write is done. Registering earlier would put the implementing agent under its own guard mid-implementation.

---

### Task 1: Unignore the tracked `.claude/` paths

**Files:**
- Modify: `.gitignore:5`
- Test: `tests/claude-hooks/test-gitignore-scope.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/claude-hooks/test-gitignore-scope.sh`:

```bash
#!/usr/bin/env bash
#
# Asserts which paths under .claude/ git tracks and which it ignores.
#
# The compiler writes .claude/skills/<slug>/SKILL.md; if git ignores that path a
# `fmanifest apply` PR arrives empty. .claude/settings.json must stay ignored
# because it holds absolute machine paths.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

FAILURES=0

pass() {
  echo "  [PASS] $1"
}

fail() {
  echo "  [FAIL] $1"
  FAILURES=$((FAILURES + 1))
}

assert_not_ignored() {
  local path="$1"
  if git -C "$REPO_ROOT" check-ignore -q "$path"; then
    fail "$path should NOT be ignored"
  else
    pass "$path is not ignored"
  fi
}

assert_ignored() {
  local path="$1"
  if git -C "$REPO_ROOT" check-ignore -q "$path"; then
    pass "$path is ignored"
  else
    fail "$path should be ignored"
  fi
}

echo "gitignore scope"
assert_not_ignored ".claude/skills/seeding-a-corpus-pr/SKILL.md"
assert_not_ignored ".claude/hooks/guard-fixtures.sh"
assert_not_ignored ".claude/settings.example.json"
assert_ignored ".claude/settings.json"

if [[ "$FAILURES" -gt 0 ]]; then
  echo "$FAILURES failure(s)"
  exit 1
fi
echo "All passed"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mkdir -p tests/claude-hooks && chmod +x tests/claude-hooks/test-gitignore-scope.sh && ./tests/claude-hooks/test-gitignore-scope.sh`
Expected: FAIL — the three `assert_not_ignored` cases fail, because `.claude/` currently matches everything.

- [ ] **Step 3: Edit `.gitignore`**

Replace the single line `.claude/` with:

```
.claude/*
!.claude/skills/
!.claude/hooks/
!.claude/settings.example.json
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./tests/claude-hooks/test-gitignore-scope.sh`
Expected: PASS — all four assertions.

- [ ] **Step 5: Commit**

```bash
git add .gitignore tests/claude-hooks/test-gitignore-scope.sh
git commit -m "fix: unignore .claude paths the compiler and hooks write to"
```

---

### Task 2: `guard-fixtures.sh`

**Files:**
- Create: `.claude/hooks/guard-fixtures.sh`
- Test: `tests/claude-hooks/test-guard-fixtures.sh`

The protection rule, from spec §5: a path under `corpus-fixtures/` or `corpus-changes/` is *protected*. Basename `CLAUDE.md` → allow. Else file exists → deny. Else new file → allow only under `corpus-changes/`.

- [ ] **Step 1: Write the failing test**

Create `tests/claude-hooks/test-guard-fixtures.sh`:

```bash
#!/usr/bin/env bash
#
# Behavioural tests for the PreToolUse fixture guard.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$REPO_ROOT/.claude/hooks/guard-fixtures.sh"

FAILURES=0

pass() {
  echo "  [PASS] $1"
}

fail() {
  echo "  [FAIL] $1"
  FAILURES=$((FAILURES + 1))
}

# assert_decision <description> <expected: deny|allow> <payload json> [PATH override]
assert_decision() {
  local description="$1"
  local expected="$2"
  local payload="$3"
  local path_override="${4:-$PATH}"

  local output
  output="$(printf '%s' "$payload" | PATH="$path_override" "$HOOK" 2>&1)" || {
    fail "$description (hook exited non-zero)"
    return
  }

  local actual="allow"
  if printf '%s' "$output" | grep -q '"permissionDecision"[[:space:]]*:[[:space:]]*"deny"'; then
    actual="deny"
  fi

  if [[ "$actual" == "$expected" ]]; then
    pass "$description"
  else
    fail "$description (expected $expected, got $actual)"
    printf '%s\n' "$output" | sed 's/^/      /'
  fi
}

edit_payload() {
  jq -nc --arg p "$1" '{tool_name: "Write", tool_input: {file_path: $p}}'
}

bash_payload() {
  jq -nc --arg c "$1" '{tool_name: "Bash", tool_input: {command: $c}}'
}

echo "guard-fixtures: existing protected files are denied"
assert_decision "write to existing vulnerable fixture" deny \
  "$(edit_payload "$REPO_ROOT/corpus-fixtures/vulnerable-server.js")"
assert_decision "write to existing seeded stub" deny \
  "$(edit_payload "$REPO_ROOT/corpus-changes/corpus-pr-0001.md")"

echo "guard-fixtures: new files"
assert_decision "new stub under corpus-changes is allowed" allow \
  "$(edit_payload "$REPO_ROOT/corpus-changes/corpus-pr-0200.md")"
assert_decision "new file under corpus-fixtures is denied" deny \
  "$(edit_payload "$REPO_ROOT/corpus-fixtures/SECURITY.md")"

echo "guard-fixtures: CLAUDE.md carve-out"
assert_decision "corpus-fixtures/CLAUDE.md is always allowed" allow \
  "$(edit_payload "$REPO_ROOT/corpus-fixtures/CLAUDE.md")"
assert_decision "corpus-changes/CLAUDE.md is always allowed" allow \
  "$(edit_payload "$REPO_ROOT/corpus-changes/CLAUDE.md")"

echo "guard-fixtures: unprotected paths"
assert_decision "scratch path is allowed" allow \
  "$(edit_payload "$REPO_ROOT/README.md")"

echo "guard-fixtures: bash commands"
assert_decision "rm of a fixture is denied" deny \
  "$(bash_payload "rm corpus-fixtures/vulnerable_handler.py")"
assert_decision "sed -i on a stub is denied" deny \
  "$(bash_payload "sed -i '' s/a/b/ corpus-changes/corpus-pr-0001.md")"
assert_decision "git reset --hard is denied" deny \
  "$(bash_payload "git reset --hard HEAD~1")"
assert_decision "ls of a fixture dir is allowed" allow \
  "$(bash_payload "ls corpus-fixtures/")"
assert_decision "unrelated command is allowed" allow \
  "$(bash_payload "npm test")"

echo "guard-fixtures: jq-missing fallback is scoped, not blanket"
# Every external the guard calls, minus jq. printf/command/cd/pwd are builtins.
EMPTY_BIN="$(mktemp -d)"
trap 'rm -rf "$EMPTY_BIN"' EXIT
for tool in cat grep dirname basename; do
  target="$(command -v "$tool")"
  ln -sf "$target" "$EMPTY_BIN/$tool"
done
assert_decision "without jq, protected path still denied" deny \
  "$(edit_payload "$REPO_ROOT/corpus-fixtures/vulnerable-server.js")" "$EMPTY_BIN"
assert_decision "without jq, scratch path still allowed" allow \
  "$(edit_payload "$REPO_ROOT/README.md")" "$EMPTY_BIN"

if [[ "$FAILURES" -gt 0 ]]; then
  echo "$FAILURES failure(s)"
  exit 1
fi
echo "All passed"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `chmod +x tests/claude-hooks/test-guard-fixtures.sh && ./tests/claude-hooks/test-guard-fixtures.sh`
Expected: FAIL — every case fails because `.claude/hooks/guard-fixtures.sh` does not exist.

- [ ] **Step 3: Write the implementation**

Create `.claude/hooks/guard-fixtures.sh`:

```bash
#!/usr/bin/env bash
#
# PreToolUse guard for this repository's seeded fixtures.
#
# corpus-fixtures/ holds deliberately vulnerable files that exist to be found by
# scanners. corpus-changes/ holds 200 seeded stubs paired with corpus/pr-NNNN
# branches. Repairing either destroys the signal the corpus exists to produce.
#
# The rule, for a path under corpus-fixtures/ or corpus-changes/:
#   basename CLAUDE.md      -> allow  (else the scoped docs lock themselves out)
#   file exists on disk     -> deny   (no modifying or deleting the fixture)
#   new file                -> allow only under corpus-changes/
#
# Reads the PreToolUse payload on stdin. Emits a deny decision on stdout, or
# nothing at all to allow. Always exits 0 — a non-zero exit is a hook error,
# not a decision.
#
# This is a speed bump, not a security boundary. The Bash matcher in particular
# is heuristic and evadable.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

deny() {
  local reason="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg reason "$reason" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $reason
      }
    }'
  else
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Blocked: this path is under corpus-fixtures/ or corpus-changes/, which hold deliberate test fixtures. (jq is not on PATH, so this guard is running in reduced-precision fallback mode.)"}}'
  fi
  exit 0
}

DENY_FIXTURE="Blocked. corpus-fixtures/ holds deliberately vulnerable files that exist to be found by security scanners, and corpus-changes/ holds 200 seeded stubs paired one-to-one with corpus/pr-NNNN branches. Modifying or deleting them destroys the fixture. See corpus-fixtures/CLAUDE.md and corpus-changes/CLAUDE.md."

payload="$(cat)"

# Fallback: without jq we cannot extract a field, so scope the guard to a raw
# substring match. A blanket deny here would reject every edit in the repo.
if ! command -v jq >/dev/null 2>&1; then
  if printf '%s' "$payload" | grep -q -e 'corpus-fixtures/' -e 'corpus-changes/'; then
    deny "$DENY_FIXTURE"
  fi
  exit 0
fi

tool_name="$(printf '%s' "$payload" | jq -r '.tool_name // empty')"

case "$tool_name" in
  Edit | Write | MultiEdit | NotebookEdit)
    path="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty')"
    [[ -n "$path" ]] || exit 0

    relative="${path#"$REPO_ROOT"/}"
    case "$relative" in
      corpus-fixtures/* | corpus-changes/*) ;;
      *) exit 0 ;;
    esac

    [[ "$(basename "$relative")" == "CLAUDE.md" ]] && exit 0
    [[ -e "$path" ]] && deny "$DENY_FIXTURE"

    case "$relative" in
      corpus-changes/*) exit 0 ;;
      *) deny "$DENY_FIXTURE Creating new files beside the vulnerable fixtures is also blocked, because it can change what a scanner reports on that directory." ;;
    esac
    ;;

  Bash)
    command_line="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty')"
    [[ -n "$command_line" ]] || exit 0

    # Wholesale-discard commands need no path to wreck the fixture.
    if printf '%s' "$command_line" |
      grep -Eq 'git[[:space:]]+(reset[[:space:]]+--hard|clean|stash)'; then
      deny "$DENY_FIXTURE This command discards working-tree state wholesale, which includes the fixture directories."
    fi

    case "$command_line" in
      *corpus-fixtures/* | *corpus-changes/*) ;;
      *) exit 0 ;;
    esac

    if printf '%s' "$command_line" |
      grep -Eq '(^|[;&|[:space:]])(rm|mv|truncate|tee)([[:space:]]|$)|sed[[:space:]][^|;&]*-i|>[[:space:]]*[^|;&>]*corpus-(fixtures|changes)/|git[[:space:]]+(checkout[[:space:]]+--|restore)'; then
      deny "$DENY_FIXTURE"
    fi
    ;;
esac

exit 0
```

- [ ] **Step 4: Run test to verify it passes**

Run: `chmod +x .claude/hooks/guard-fixtures.sh && ./tests/claude-hooks/test-guard-fixtures.sh`
Expected: PASS — all 13 assertions.

- [ ] **Step 5: Lint the new script**

Run: `./scripts/lint-shell.sh .claude/hooks/guard-fixtures.sh`
Expected: `Linting 1 shell files` and no ShellCheck output.

If ShellCheck flags `SC2310`/`SC2312` style issues under `set -e`, fix them rather than adding a `# shellcheck disable` — the repo lints at `--severity=warning` and these are below it, so they should not appear.

- [ ] **Step 6: Commit**

```bash
git add .claude/hooks/guard-fixtures.sh tests/claude-hooks/test-guard-fixtures.sh
git update-index --chmod=+x .claude/hooks/guard-fixtures.sh
git commit -m "feat: add PreToolUse guard for corpus fixtures"
```

---

### Task 3: `lint-shell-on-edit.sh`

**Files:**
- Create: `.claude/hooks/lint-shell-on-edit.sh`
- Test: `tests/claude-hooks/test-lint-shell-on-edit.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/claude-hooks/test-lint-shell-on-edit.sh`:

```bash
#!/usr/bin/env bash
#
# Behavioural tests for the PostToolUse shell linting hook.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$REPO_ROOT/.claude/hooks/lint-shell-on-edit.sh"

FAILURES=0
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

pass() {
  echo "  [PASS] $1"
}

fail() {
  echo "  [FAIL] $1"
  FAILURES=$((FAILURES + 1))
}

# assert_exit <description> <expected code> <file path> [PATH override]
assert_exit() {
  local description="$1"
  local expected="$2"
  local path="$3"
  local path_override="${4:-$PATH}"

  local actual=0
  printf '%s' "$(jq -nc --arg p "$path" '{tool_name: "Write", tool_input: {file_path: $p}}')" |
    PATH="$path_override" "$HOOK" >/dev/null 2>&1 || actual=$?

  if [[ "$actual" -eq "$expected" ]]; then
    pass "$description"
  else
    fail "$description (expected exit $expected, got $actual)"
  fi
}

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "SKIP: shellcheck is not on PATH; install it to run these tests"
  exit 0
fi

cat >"$WORK_DIR/clean.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "hello"
EOF

# SC2086: unquoted variable expansion — a warning-severity finding.
cat >"$WORK_DIR/dirty.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
target=$1
ls $target
EOF

printf 'not shell\n' >"$WORK_DIR/notes.md"

echo "lint-shell-on-edit"
assert_exit "clean shell file passes" 0 "$WORK_DIR/clean.sh"
assert_exit "shellcheck warning exits 2" 2 "$WORK_DIR/dirty.sh"
assert_exit "non-shell file is ignored" 0 "$WORK_DIR/notes.md"
assert_exit "missing file is ignored" 0 "$WORK_DIR/absent.sh"

echo "lint-shell-on-edit: fails open"
# Every external the lint hook calls before it gives up, minus shellcheck.
EMPTY_BIN="$(mktemp -d)"
for tool in cat jq dirname; do
  target="$(command -v "$tool")"
  ln -sf "$target" "$EMPTY_BIN/$tool"
done
assert_exit "without shellcheck, exits 0" 0 "$WORK_DIR/dirty.sh" "$EMPTY_BIN"
rm -rf "$EMPTY_BIN"

if [[ "$FAILURES" -gt 0 ]]; then
  echo "$FAILURES failure(s)"
  exit 1
fi
echo "All passed"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `chmod +x tests/claude-hooks/test-lint-shell-on-edit.sh && ./tests/claude-hooks/test-lint-shell-on-edit.sh`
Expected: FAIL — the hook does not exist. (If it prints `SKIP`, install ShellCheck first — see Prerequisites.)

- [ ] **Step 3: Write the implementation**

Create `.claude/hooks/lint-shell-on-edit.sh`:

```bash
#!/usr/bin/env bash
#
# PostToolUse hook: ShellCheck a shell file the agent just edited.
#
# Exit 2 is deliberate and load-bearing. For PostToolUse, exit 2 is the only
# code that routes stderr back to the model; any other non-zero code surfaces
# to the user instead, which is noise rather than feedback.
#
# Fails open. A missing jq or shellcheck exits 0 silently, because an advisory
# linter that breaks every edit on an unprovisioned machine is worse than one
# that is quietly absent. scripts/lint-shell.sh calls `require_tool shellcheck`
# and dies with exit 1, so this script checks PATH itself rather than letting
# that surface.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

command -v jq >/dev/null 2>&1 || exit 0
command -v shellcheck >/dev/null 2>&1 || exit 0

payload="$(cat)"
path="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty')"

[[ -n "$path" ]] || exit 0
[[ -f "$path" ]] || exit 0

# Mirrors is_shell_file() in scripts/lint-shell.sh.
is_shell_file() {
  local candidate="$1"
  local first_line=""

  case "$candidate" in
    *.sh) return 0 ;;
  esac

  IFS= read -r first_line <"$candidate" || true
  [[ "$first_line" =~ ^#!.*[/[:space:]](bash|dash|ksh|sh)([[:space:]]|$) ]]
}

is_shell_file "$path" || exit 0

if ! output="$("$REPO_ROOT/scripts/lint-shell.sh" "$path" 2>&1)"; then
  printf '%s\n' "$output" >&2
  exit 2
fi

exit 0
```

- [ ] **Step 4: Run test to verify it passes**

Run: `chmod +x .claude/hooks/lint-shell-on-edit.sh && ./tests/claude-hooks/test-lint-shell-on-edit.sh`
Expected: PASS — all five assertions.

- [ ] **Step 5: Lint both hooks**

Run: `./scripts/lint-shell.sh .claude/hooks/lint-shell-on-edit.sh tests/claude-hooks/*.sh`
Expected: no ShellCheck output.

- [ ] **Step 6: Commit**

```bash
git add .claude/hooks/lint-shell-on-edit.sh tests/claude-hooks/test-lint-shell-on-edit.sh
git update-index --chmod=+x .claude/hooks/lint-shell-on-edit.sh
git commit -m "feat: add PostToolUse shell lint hook"
```

---

### Task 4: `settings.example.json`

**Files:**
- Create: `.claude/settings.example.json`

- [ ] **Step 1: Write the file**

Paths are `$CLAUDE_PROJECT_DIR`-relative so the file carries no machine-specific state.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit|NotebookEdit",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR/.claude/hooks/guard-fixtures.sh\""
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR/.claude/hooks/guard-fixtures.sh\""
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR/.claude/hooks/lint-shell-on-edit.sh\""
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: Verify it is valid JSON and tracked**

Run: `jq . .claude/settings.example.json >/dev/null && git check-ignore -v .claude/settings.example.json; echo "exit=$?"`
Expected: `jq` prints nothing, `git check-ignore` prints nothing, `exit=1` (meaning: not ignored).

- [ ] **Step 3: Commit**

```bash
git add .claude/settings.example.json
git commit -m "docs: add example settings for the enforcement hooks"
```

---

### Task 5: Corpus guardrail docs

**Files:**
- Create: `corpus-changes/CLAUDE.md`
- Create: `corpus-fixtures/CLAUDE.md`

These two go first among the prose files because they are the highest-value guardrails and because the guard's `CLAUDE.md` carve-out is what lets them be corrected later.

- [ ] **Step 1: Write `corpus-changes/CLAUDE.md`**

```markdown
# corpus-changes/

These 200 files are **seeded test fixtures, not work items.**

Each `corpus-pr-NNNN.md` pairs one-to-one with a remote branch `origin/corpus/pr-NNNN`. 67 of the
200 carry a `-fail` suffix on **both** the branch name and the stub filename
(`corpus/pr-0000-fail` ↔ `corpus-pr-0000-fail.md`); `.github/workflows/corpus-ci.yml` fails CI on
any branch matching `*-fail`, which is how the corpus produces a red-CI signal on demand.

## Do not

- Edit, renumber, reword, or reformat an existing stub. A `PreToolUse` hook blocks this.
- Regenerate the set, or "fix" the numbering gaps — there are none, and looking for them wastes time.
- Treat the `Derived from <sha>` line as a task. It is provenance pointing at the upstream commit a
  stub was modelled on, not an instruction to reproduce that commit.

## To add one

Use the `seeding-a-corpus-pr` skill. Creating a **new** stub here is allowed; the guard only blocks
changes to files that already exist.
```

- [ ] **Step 2: Write `corpus-fixtures/CLAUDE.md`**

```markdown
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
```

- [ ] **Step 3: Verify both files exist and the guard tolerated them**

Run: `ls corpus-changes/CLAUDE.md corpus-fixtures/CLAUDE.md`
Expected: both listed. (The hooks are not registered until Task 9, so nothing should have interfered either way.)

- [ ] **Step 4: Commit**

```bash
git add corpus-changes/CLAUDE.md corpus-fixtures/CLAUDE.md
git commit -m "docs: add guardrails for the corpus fixture directories"
```

---

### Task 6: Remaining scoped docs

**Files:**
- Create: `skills/CLAUDE.md`, `tests/CLAUDE.md`, `hooks/CLAUDE.md`, `scripts/CLAUDE.md`

- [ ] **Step 1: Write `skills/CLAUDE.md`**

```markdown
# skills/

The 14 Superpowers plugin skills. These are behaviour-shaping content, closer to code than to prose:
they are tuned against real agent sessions, and small wording changes measurably change what agents do.

## Rules

- **Frontmatter is exactly `name` and `description`.** Nothing else. `description` is the trigger
  text — it is what a model matches against when deciding to invoke the skill, so it describes
  *when to use this*, not what it contains.
- **"Your human partner" is deliberate.** It is not interchangeable with "the user". Do not
  normalise it.
- **Do not reformat to Anthropic's published skill-authoring guidance.** This project's conventions
  diverge from it on purpose.
- **Do not soften the rigid skills.** Red Flags tables, rationalization lists, and Iron Law framings
  in `test-driven-development`, `systematic-debugging`, and `verification-before-completion` are the
  load-bearing parts. They pre-name the excuses an agent reaches for; paraphrasing removes the effect.
- **Behavioural changes need evidence.** Use `superpowers:writing-skills` to develop and test a
  change. Eval scenarios live in the separate `superpowers-evals` repo, cloned into a gitignored
  `evals/` (absent from this checkout).

## Related surfaces

`.codex-plugin/plugin.json` and `.claude-plugin/plugin.json` are committed plugin manifests.
`scripts/sync-to-codex-plugin.sh` pushes this whole checkout to an external fork
(`prime-radiant-inc/openai-codex-plugins`) and opens a PR there — it is a release step, not
something to run after an edit. `scripts/package-codex-plugin.sh` builds the portal archive.
```

- [ ] **Step 2: Write `tests/CLAUDE.md`**

```markdown
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

**Cheap and safe locally:** `claude-hooks/`, `shell-lint/`, `codex/`, `codex-plugin-sync/`,
`kimi/`, `hooks/`, `brainstorm-server/`.

**Expensive — do not run casually:** `claude-code/` and `explicit-skill-requests/` drive the real
`claude` CLI in headless mode. They cost tokens and take minutes. Run them deliberately, not as
part of a general "run the tests" sweep, and say so before you do.

`opencode/` needs `setup.sh` first.

## Writing a test

Follow the existing shape: `#!/usr/bin/env bash`, `set -euo pipefail`, a `SCRIPT_DIR`/`REPO_ROOT`
pair resolved from `${BASH_SOURCE[0]}`, `pass`/`fail` helpers incrementing a `FAILURES` counter,
`mktemp -d` with a `trap ... EXIT` cleanup, and a non-zero exit when `FAILURES` is non-zero.
`tests/hooks/test-session-start.sh` is the reference.
```

- [ ] **Step 3: Write `hooks/CLAUDE.md`**

```markdown
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
```

- [ ] **Step 4: Write `scripts/CLAUDE.md`**

```markdown
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
```

- [ ] **Step 5: Verify all four exist**

Run: `ls skills/CLAUDE.md tests/CLAUDE.md hooks/CLAUDE.md scripts/CLAUDE.md`
Expected: all four listed.

- [ ] **Step 6: Commit**

```bash
git add skills/CLAUDE.md tests/CLAUDE.md hooks/CLAUDE.md scripts/CLAUDE.md
git commit -m "docs: add scoped guidance for skills, tests, hooks and scripts"
```

---

### Task 7: Rewrite root `CLAUDE.md`

**Files:**
- Replace: `CLAUDE.md`

The current file is 8873 bytes of upstream contributor guidance for `obra/superpowers`. `AGENTS.md`
is a symlink to it and needs no separate change.

- [ ] **Step 1: Confirm no compiler blocks would be lost**

Run: `grep -c 'fleetmanifest:start' CLAUDE.md || true`
Expected: `0`. If it is non-zero, **stop** — the file contains compiler-managed blocks that must be
preserved verbatim, and this task needs revisiting.

- [ ] **Step 2: Replace the file**

```markdown
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
so the two coexist.

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

- **This file**, as delimited blocks (`<!-- fleetmanifest:start slug=… -->`). Everything outside
  those markers is preserved byte-for-byte, and new blocks are appended at the end. Leave the tail
  of this file alone.
- **`.claude/skills/<slug>/SKILL.md`**, as whole files. A hand-written skill at a colliding slug
  will be taken over — reported as `adopted`, not silently.

`.gitignore` is narrowed so both paths are visible to git. Widening it back to a blanket `.claude/`
would make `fmanifest apply` produce an empty PR.

## Known dead configuration

Documented so nobody rediscovers them as bugs:

- **`.pre-commit-config.yaml` is a no-op.** All three hooks match `^evals/.*\.py$`, and `evals/` is
  both gitignored and absent from this checkout.
- **`AGENTS.md` is a symlink to this file.** Harmless today. If `agents-md` is ever added to
  `compiler.targets`, both targets would resolve to the same inode and the compiler would hit
  `duplicate-slug` and refuse to write anything at all.

## Contributing upstream

Don't, from here. This fork takes no external contributions and has no `dev` branch. Work intended
for `obra/superpowers` belongs in a checkout of that repo, under its own contributor guidelines.
```

- [ ] **Step 3: Verify the upstream content is gone and the symlink still resolves**

Run:
```bash
grep -ciE 'rejection rate|PULL_REQUEST_TEMPLATE|target the `dev` branch' CLAUDE.md || true
readlink AGENTS.md && head -1 AGENTS.md
```
Expected: `0`, then `CLAUDE.md`, then `# fleetmanifest-test-corpus`.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: rewrite root CLAUDE.md for this fork"
```

---

### Task 8: The four project skills

**Files:**
- Create: `.claude/skills/seeding-a-corpus-pr/SKILL.md`
- Create: `.claude/skills/running-corpus-tests/SKILL.md`
- Create: `.claude/skills/editing-a-superpowers-skill/SKILL.md`
- Create: `.claude/skills/shell-script-standards/SKILL.md`

Frontmatter is exactly `name` and `description`, matching what the FleetManifest compiler emits.

- [ ] **Step 1: Write `seeding-a-corpus-pr`**

```markdown
---
name: seeding-a-corpus-pr
description: Use when adding a new seeded corpus PR to this repo - covers branch naming, the -fail convention, and the paired stub file
---

# Seeding a Corpus PR

A corpus entry is a **pair**: a remote branch and a stub file. Both must exist, and their names must
agree. There are 200 such pairs; 67 carry a `-fail` suffix.

## The pair

| Part | Form | Example |
|---|---|---|
| Branch | `corpus/pr-NNNN` | `corpus/pr-0042` |
| Stub | `corpus-changes/corpus-pr-NNNN.md` | `corpus-changes/corpus-pr-0042.md` |

`NNNN` is zero-padded to four digits. To arm a CI failure, append `-fail` to **both**:
`corpus/pr-0042-fail` and `corpus-changes/corpus-pr-0042-fail.md`.
`.github/workflows/corpus-ci.yml` matches `*-fail` on `github.head_ref` and exits 1.

A mismatched pair — `-fail` on one side only — produces a branch whose CI outcome disagrees with its
stub. That is the single most common way to corrupt the corpus.

## Stub format

Three parts, blank-line separated:

```markdown
# <type>: <subject>

Derived from <full 40-char sha>.

Corpus entry <N>.
```

`<type>: <subject>` reads like a commit subject (`docs:`, `chore:`, `fix:`). The `Derived from` sha
is the upstream commit the entry was modelled on — provenance only. `<N>` is the integer form of
`NNNN` without padding.

## Steps

1. Pick the next free `NNNN`: `ls corpus-changes/ | tail -1`.
2. Decide whether it fails. If so, both names take `-fail`.
3. Create the stub. Creating a **new** file under `corpus-changes/` is permitted by the guard hook;
   editing an existing one is not.
4. Branch, commit, push: `git switch -c corpus/pr-NNNN[-fail]`.
5. Confirm the pair agrees before opening the PR.

## Do not

- Renumber, reword, or reformat existing stubs. They are fixtures.
- Create a stub without its branch, or a branch without its stub.
```

- [ ] **Step 2: Write `running-corpus-tests`**

```markdown
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
| Any shell script | `./scripts/lint-shell.sh` then `./tests/shell-lint/test-lint-shell.sh` |
| `hooks/session-start`, `hooks/*.json` | `./tests/hooks/test-session-start.sh` |
| Brainstorm server JS | `cd tests/brainstorm-server && npm test` |
| OpenCode plugin | `./tests/opencode/setup.sh` then `./tests/opencode/run-tests.sh` |
| Codex packaging or sync | `./tests/codex/test-package-codex-plugin.sh`, `./tests/codex-plugin-sync/test-sync-to-codex-plugin.sh` |
| Kimi manifest | `./tests/kimi/run-tests.sh` |
| Antigravity | `./tests/antigravity/run-tests.sh` |
| Pi extension | `node tests/pi/test-pi-extension.mjs` |

## The expensive ones

`tests/claude-code/` and `tests/explicit-skill-requests/` drive the real `claude` CLI in headless
mode. They consume tokens and take minutes to tens of minutes.

**Do not run them as part of a general "run the tests" sweep.** Run them only when the change is to
skill content that they cover, and tell your human partner before you start.

## Prerequisites

`shellcheck` and `shfmt` for the lint suites; `node` and `npm` for `brainstorm-server/`;
`tests/opencode/setup.sh` before the OpenCode suite. There is no repo-wide test runner — invoke the
suite you need.
```

- [ ] **Step 3: Write `editing-a-superpowers-skill`**

```markdown
---
name: editing-a-superpowers-skill
description: Use before changing anything under skills/ - the bar for modifying behaviour-shaping skill content
---

# Editing a Superpowers Skill

The 14 skills under `skills/` are behaviour-shaping content. Treat them as code that runs on a model:
tuned against real sessions, where wording changes outcomes.

## Before you edit

Ask which of these you are doing:

- **Fixing a factual error** (a wrong path, a stale command) — go ahead. Verify the correction against
  the checkout first.
- **Changing what an agent does** — you need evidence. Use `superpowers:writing-skills` to develop
  the change, and pressure-test it across sessions. "It reads better" is not evidence.
- **Reformatting to match some other style guide** — don't. This project's conventions diverge from
  Anthropic's published skill guidance deliberately.

## Rules

- Frontmatter is exactly `name` and `description`. `description` is trigger text: it says *when* to
  use the skill, not what it contains.
- "Your human partner" is deliberate and not interchangeable with "the user".
- Do not soften Red Flags tables, rationalization lists, or Iron Law framings. They work by
  pre-naming the excuse an agent is about to make; paraphrase and the effect is gone.
- Keep the `dot` process diagrams in sync with the prose when you change a flow.

## After you edit

Skill content is prose, so nothing lints it. Check by hand:

- Frontmatter still parses and has exactly the two fields.
- Every file path and command you touched still resolves in this checkout.
- Cross-references to other skills still name skills that exist (`ls skills/`).

`.codex-plugin/` and `.claude-plugin/` hold committed plugin manifests.
`scripts/sync-to-codex-plugin.sh` is a release step that pushes to an external fork — not something
to run after an edit.
```

- [ ] **Step 4: Write `shell-script-standards`**

```markdown
---
name: shell-script-standards
description: Use when writing or changing any shell script in this repo - the conventions and how to check them
---

# Shell Script Standards

42 tracked shell files: 38 `*.sh` plus four extensionless shebang scripts (`hooks/session-start` and
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
./scripts/lint-shell.sh --all           # all 42
./scripts/lint-shell.sh --format        # shfmt -w, then lint
./scripts/lint-shell.sh --strict        # extra optional rules
./scripts/lint-shell.sh path/to/one.sh
```

Needs `shellcheck` on PATH (and `shfmt` for `--format`); the script exits 1 if either is missing.

If the `lint-shell-on-edit` hook is registered, ShellCheck runs automatically on every shell file you
edit and feeds failures straight back to you.
```

- [ ] **Step 5: Verify frontmatter shape**

Run:
```bash
for f in .claude/skills/*/SKILL.md; do
  echo "== $f"
  sed -n '1,5p' "$f"
done
```
Expected: each file opens `---`, `name: <dir name>`, `description: ...`, `---`, blank. No other keys.

- [ ] **Step 6: Verify they are tracked**

Run: `git status --short .claude/skills/`
Expected: four `??` entries — not ignored.

- [ ] **Step 7: Commit**

```bash
git add .claude/skills/
git commit -m "feat: add project skills for corpus procedures"
```

---

### Task 9: Register the hooks and run the full verification sweep

**Files:**
- Modify: `.claude/settings.json` (untracked — local only)

- [ ] **Step 1: Merge the hook registration**

Merge `.claude/settings.example.json` into `.claude/settings.json`, preserving every existing
`capture.js` entry:

Both files define `PostToolUse`, so a plain `*` or `+` merge on `.hooks` replaces FleetManifest's
capture entry for that event and silently drops it (verified: 9 capture commands survive instead of
10). The merge must concatenate the arrays **per event key**:

```bash
jq -s '.[0] as $a | .[1] as $b | $a * {hooks: (
  ((($a.hooks // {}) | to_entries) + (($b.hooks // {}) | to_entries))
  | group_by(.key)
  | map({key: .[0].key, value: (map(.value) | add)})
  | from_entries)}' \
  .claude/settings.json .claude/settings.example.json > .claude/settings.merged.json
jq . .claude/settings.merged.json >/dev/null \
  && mv .claude/settings.merged.json .claude/settings.json
```

Then confirm both hook families survived:

```bash
jq '.hooks | keys' .claude/settings.json
jq '[.. | .command? // empty] | map(select(test("capture.js"))) | length' .claude/settings.json
jq '[.. | .command? // empty] | map(select(test("guard-fixtures|lint-shell-on-edit"))) | length' .claude/settings.json
```
Expected: the key list includes `PreToolUse`, `PostToolUse`, `SessionStart` and the rest; `10` capture
commands; `3` enforcement commands.

- [ ] **Step 2: Run every automated check**

```bash
./tests/claude-hooks/test-gitignore-scope.sh
./tests/claude-hooks/test-guard-fixtures.sh
./tests/claude-hooks/test-lint-shell-on-edit.sh
./scripts/lint-shell.sh --all
./tests/shell-lint/test-lint-shell.sh
```
Expected: `All passed` from each of the three hook suites, no ShellCheck output from `--all`, and a
pass from the shell-lint suite.

- [ ] **Step 3: Verify the executable bits**

Run: `git ls-files -s .claude/hooks/ tests/claude-hooks/`
Expected: every line begins `100755`. If any is `100644`:

```bash
git update-index --chmod=+x <path>
```

- [ ] **Step 4: Walk the spec's verification list**

Check each of the ten criteria in
`docs/superpowers/specs/2026-08-16-corpus-repo-setup-design.md` § Verification. Criteria 1, 3–7 are
covered by the automated suites above. Confirm the remaining four by hand:

- **8** — `grep -ciE 'rejection rate|PULL_REQUEST_TEMPLATE|dev branch' CLAUDE.md` returns 0, and
  `tail -3 CLAUDE.md` shows no marker content.
- **9** — all six scoped `CLAUDE.md` files and four `SKILL.md` files exist at their specified paths.
- **10** — the branch/stub naming in `seeding-a-corpus-pr` matches an actual pair
  (`git branch -r | grep pr-0000` against `ls corpus-changes/ | head -1`), and every directory named
  in `running-corpus-tests` exists under `tests/`.

- [ ] **Step 5: Live-test the guard in this session**

Attempt a `Write` to `corpus-fixtures/vulnerable-server.js`. Expected: denied, with the fixture
explanation. Then attempt a `Write` to a scratch path. Expected: allowed.

If the guard denies the scratch path too, the hook is over-matching — stop and fix it before
continuing; that failure mode makes the repo unusable.

- [ ] **Step 6: Commit any executable-bit fixes**

```bash
git status --short
git commit -am "chore: fix executable bits on hook scripts" || echo "nothing to commit"
```

---

## Self-Review Notes

**Spec coverage.** §1 → Task 7. §2 → Tasks 5–6. §3 → Task 8. §4 → Tasks 1 and 4. §5 → Tasks 2–3 and 9.
Verification §1–7 → automated suites in Tasks 1–3 and 9; §8–10 → Task 9 Step 4.

**Deviation from the spec, deliberate.** The spec's verification section lists behaviours; this plan
implements them as three bash suites under `tests/claude-hooks/` rather than as one-off manual
checks, matching the repo's existing test conventions. That directory is new and is named in
`tests/CLAUDE.md`.

**Naming consistency.** `guard-fixtures.sh` and `lint-shell-on-edit.sh` are used identically in the
spec, the hook files, the tests, `settings.example.json`, and the docs. The protection rule's three
branches are stated once in the spec and mirrored exactly in the hook's header comment.

**Known gap, accepted.** The Bash matcher is heuristic — `cd corpus-fixtures && rm x` evades it, as
does variable indirection. Documented as such in the hook header, the spec, and
`corpus-fixtures/CLAUDE.md`.
