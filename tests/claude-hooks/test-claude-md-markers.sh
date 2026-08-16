#!/usr/bin/env bash
#
# Guards root CLAUDE.md against a self-inflicted compiler failure.
#
# FleetManifest's compiler fences its generated prose between HTML comment
# markers, and it finds them with a plain regex over the raw file. Markdown
# backticks hide nothing from it. A start marker written into the prose as an
# example therefore parses as a real one, and having no matching end marker it
# is an `unterminated` error — which the compiler answers by writing NOTHING at
# all, for every target, not by skipping the offending file.
#
# So: any marker in CLAUDE.md must be balanced. Documentation that wants to talk
# about markers must name them without the surrounding comment syntax.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET="$REPO_ROOT/CLAUDE.md"

FAILURES=0

pass() {
  echo "  [PASS] $1"
}

fail() {
  echo "  [FAIL] $1"
  FAILURES=$((FAILURES + 1))
}

# Mirrors MARKER in packages/compiler/src/markers.ts:
#   new RegExp(`<!--\\s*${PREFIX}:(start|end)\\s+(.*?)\\s*-->`, 'g')
# `grep` exits 1 when it matches nothing, which under `set -euo pipefail` would
# kill this script on the healthy path — zero markers is the expected state.
count_markers() {
  local kind="$1"
  local matches=""

  matches="$(grep -cE "<!--[[:space:]]*fleetmanifest:${kind}[[:space:]]+.*-->" "$TARGET" || true)"
  printf '%s' "${matches:-0}"
}

echo "CLAUDE.md compiler markers"

starts="$(count_markers start)"
ends="$(count_markers end)"

if [[ "$starts" -eq "$ends" ]]; then
  pass "start markers ($starts) balance end markers ($ends)"
else
  fail "unbalanced markers: $starts start, $ends end — the compiler would refuse to write anything"
fi

if [[ "$starts" -eq 0 ]]; then
  pass "no compiler-managed blocks present (hand-written file is intact)"
elif [[ "$starts" -eq "$ends" ]]; then
  echo "  [INFO] $starts compiler-managed block(s) present and balanced"
fi

if [[ "$FAILURES" -gt 0 ]]; then
  echo "$FAILURES failure(s)"
  exit 1
fi
echo "All passed"
