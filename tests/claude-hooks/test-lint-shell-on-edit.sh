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
  printf '%s' "$(jq -nc --arg p "$path" '{tool_name: "Write", tool_input: {file_path: $p}}')" \
    | PATH="$path_override" "$HOOK" >/dev/null 2>&1 || actual=$?

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

# SC2034: unused variable — a warning-severity finding. (SC2086, unquoted
# expansion, is info severity in shellcheck 0.11.0 and would not trip
# --severity=warning, so it doesn't serve as the fixture here.)
cat >"$WORK_DIR/dirty.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
unused_var="hello"
echo "world"
EOF

printf 'not shell\n' >"$WORK_DIR/notes.md"

echo "lint-shell-on-edit"
assert_exit "clean shell file passes" 0 "$WORK_DIR/clean.sh"
assert_exit "shellcheck warning exits 2" 2 "$WORK_DIR/dirty.sh"
assert_exit "non-shell file is ignored" 0 "$WORK_DIR/notes.md"
assert_exit "missing file is ignored" 0 "$WORK_DIR/absent.sh"

echo "lint-shell-on-edit: fails open"
# Every external the lint hook calls before it gives up, minus shellcheck.
# `bash` is required too: the hook runs as a subprocess and `#!/usr/bin/env bash`
# resolves the interpreter on this restricted PATH.
EMPTY_BIN="$(mktemp -d)"
for tool in cat jq dirname bash; do
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
