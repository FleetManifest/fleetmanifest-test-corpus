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
  if ! output="$(printf '%s' "$payload" | PATH="$path_override" "$HOOK" 2>&1)"; then
    fail "$description (hook exited non-zero)"
    printf '%s\n' "$output" | sed 's/^/      /'
    return
  fi

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

notebook_payload() {
  jq -nc --arg p "$1" '{tool_name: "NotebookEdit", tool_input: {notebook_path: $p}}'
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

echo "guard-fixtures: adversarial bypasses"
assert_decision "git checkout <ref> -- <path> restoring a stub is denied" deny \
  "$(bash_payload "git checkout origin/corpus/pr-0001 -- corpus-changes/corpus-pr-0001.md")"
assert_decision "NotebookEdit on a protected notebook is denied" deny \
  "$(notebook_payload "$REPO_ROOT/corpus-fixtures/x.ipynb")"
assert_decision "dot-dot traversal into a protected path is denied" deny \
  "$(edit_payload "$REPO_ROOT/docs/../corpus-fixtures/vulnerable-server.js")"
assert_decision "mutating verb in an unrelated segment is allowed" allow \
  "$(bash_payload "rm -f /tmp/build.log && cat corpus-fixtures/vulnerable-server.js")"
assert_decision "mutating verb in an unrelated segment (semicolon) is allowed" allow \
  "$(bash_payload "mv /tmp/a /tmp/b; grep -r TODO corpus-changes/")"
assert_decision "cp onto a protected path is denied" deny \
  "$(bash_payload "cp evil.js corpus-fixtures/vulnerable-server.js")"

echo "guard-fixtures: regression guards"
assert_decision "git checkout with no protected path is allowed" allow \
  "$(bash_payload "git checkout main")"
assert_decision "cat of a protected path is allowed" allow \
  "$(bash_payload "cat corpus-fixtures/vulnerable-server.js")"
assert_decision "grep of a protected path is allowed" allow \
  "$(bash_payload "grep -r foo corpus-changes/")"
assert_decision "rm outside the repo fixtures is allowed" allow \
  "$(bash_payload "rm -rf /tmp/x")"
assert_decision "append redirect into a protected path is denied" deny \
  "$(bash_payload "echo pwned >> corpus-fixtures/vulnerable-server.js")"

echo "guard-fixtures: pipelines are one command, not separate segments"
assert_decision "xargs rm through a pipe is denied" deny \
  "$(bash_payload "echo corpus-fixtures/vulnerable-server.js | xargs rm -f")"
assert_decision "find -delete is denied" deny \
  "$(bash_payload "find corpus-fixtures/ -name '*.js' -delete")"
assert_decision "find without -delete is allowed" allow \
  "$(bash_payload "find corpus-fixtures/ -name '*.js'")"
assert_decision "cat piped to grep is allowed" allow \
  "$(bash_payload "cat corpus-fixtures/vulnerable-server.js | grep -n eval")"

echo "guard-fixtures: additional mutating verbs"
assert_decision "perl -i is denied" deny \
  "$(bash_payload "perl -i -pe 's/a/b/' corpus-changes/corpus-pr-0001.md")"
assert_decision "rsync onto a fixture is denied" deny \
  "$(bash_payload "rsync -a /tmp/evil.js corpus-fixtures/vulnerable-server.js")"
assert_decision "shred is denied" deny \
  "$(bash_payload "shred -u corpus-fixtures/vulnerable-server.js")"
assert_decision "install is denied" deny \
  "$(bash_payload "install -m 644 /tmp/evil.js corpus-fixtures/vulnerable-server.js")"
assert_decision "subshell without a space is denied" deny \
  "$(bash_payload "(rm corpus-fixtures/vulnerable-server.js)")"
assert_decision "command substitution is denied" deny \
  "$(bash_payload "echo \$(rm corpus-fixtures/vulnerable-server.js)")"
assert_decision "git rm is denied" deny \
  "$(bash_payload "git rm corpus-changes/corpus-pr-0001.md")"

echo "guard-fixtures: path boundaries and comments do not false-positive"
assert_decision "unrelated dir sharing a name substring is allowed" allow \
  "$(bash_payload "rm not-corpus-fixtures/old-backup.js")"
assert_decision "protected path only in a trailing comment is allowed" allow \
  "$(bash_payload "rm /tmp/scratch.js  # nothing to do with corpus-fixtures/")"
assert_decision "leading ./ still matches" deny \
  "$(bash_payload "rm ./corpus-fixtures/vulnerable-server.js")"

echo "guard-fixtures: Bash honours the CLAUDE.md carve-out too"
assert_decision "appending to corpus-fixtures/CLAUDE.md is allowed" allow \
  "$(bash_payload "echo x >> corpus-fixtures/CLAUDE.md")"
assert_decision "appending to corpus-changes/CLAUDE.md is allowed" allow \
  "$(bash_payload "echo x >> corpus-changes/CLAUDE.md")"
assert_decision "CLAUDE.md carve-out does not shield a sibling fixture" deny \
  "$(bash_payload "cp corpus-fixtures/CLAUDE.md corpus-fixtures/vulnerable-server.js")"

echo "guard-fixtures: jq-missing fallback is scoped, not blanket"
# Every external the guard calls, minus jq. printf/command/cd/pwd are builtins.
# bash itself must resolve too: the hook is a fresh subprocess, and its
# `#!/usr/bin/env bash` shebang needs `bash` on this same restricted PATH.
EMPTY_BIN="$(mktemp -d)"
trap 'rm -rf "$EMPTY_BIN"' EXIT
for tool in cat grep dirname basename bash; do
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
