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
    if printf '%s' "$command_line" \
      | grep -Eq 'git[[:space:]]+(reset[[:space:]]+--hard|clean|stash)'; then
      deny "$DENY_FIXTURE This command discards working-tree state wholesale, which includes the fixture directories."
    fi

    case "$command_line" in
      *corpus-fixtures/* | *corpus-changes/*) ;;
      *) exit 0 ;;
    esac

    if printf '%s' "$command_line" \
      | grep -Eq '(^|[;&|[:space:]])(rm|mv|truncate|tee)([[:space:]]|$)|sed[[:space:]][^|;&]*-i|>[[:space:]]*[^|;&>]*corpus-(fixtures|changes)/|git[[:space:]]+(checkout[[:space:]]+--|restore)'; then
      deny "$DENY_FIXTURE"
    fi
    ;;
esac

exit 0
