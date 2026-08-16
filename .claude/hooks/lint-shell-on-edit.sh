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
