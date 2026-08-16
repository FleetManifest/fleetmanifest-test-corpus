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
