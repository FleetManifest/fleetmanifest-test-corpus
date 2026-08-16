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
# is heuristic. Known and accepted limits: it reads command text, so it cannot
# follow a path built from a variable, reached after a `cd`, or hidden behind a
# symlink; and it will deny a harmless quoted string that happens to contain
# both a mutating verb and a protected path (`echo 'do not rm corpus-fixtures/x'`),
# because nothing in the text distinguishes that from the real thing.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"

# Canonicalise a path's parent directory so a textual `..`/symlink traversal
# can't disguise a protected path as an unprotected one. Falls back to the
# input unchanged when the parent doesn't exist yet (a new file in a new
# directory) — there's nothing on disk to canonicalise in that case, and the
# textual prefix check downstream still does the right thing.
resolve_path() {
  local input="$1"
  local parent canonical_parent
  parent="$(dirname -- "$input")"
  if canonical_parent="$(cd -- "$parent" 2>/dev/null && pwd -P)"; then
    printf '%s/%s' "$canonical_parent" "$(basename -- "$input")"
  else
    printf '%s' "$input"
  fi
}

# Drop a trailing comment before matching. A protected path named only in a
# comment is documentation, not an operation on the fixture.
strip_comment() {
  printf '%s' "$1" | sed -e 's/[[:space:]]#.*$//' -e 's/^#.*$//'
}

# True when the text operates on a protected path.
#
# Two refinements over a plain substring test. The reference must sit on a path
# boundary, so `not-corpus-fixtures/` and `mycorpus-changes/` are ordinary
# directories rather than fixtures. And the two scoped CLAUDE.md files are
# exempt, matching the carve-out the Edit/Write branch already makes — without
# this, `corpus-fixtures/CLAUDE.md` could be written through one tool and not
# the other, and its own text would be wrong about the rule.
mentions_protected() {
  local text="$1"
  text="${text//corpus-fixtures\/CLAUDE.md/}"
  text="${text//corpus-changes\/CLAUDE.md/}"
  printf '%s' "$text" | grep -Eq '(^|[^[:alnum:]_.-])(\./)?corpus-(fixtures|changes)/'
}

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
    # NotebookEdit carries its path in a differently-named field.
    path="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')"
    [[ -n "$path" ]] || exit 0

    resolved="$(resolve_path "$path")"
    relative="${resolved#"$REPO_ROOT"/}"
    case "$relative" in
      corpus-fixtures/* | corpus-changes/*) ;;
      *) exit 0 ;;
    esac

    [[ "$(basename "$relative")" == "CLAUDE.md" ]] && exit 0
    [[ -e "$resolved" ]] && deny "$DENY_FIXTURE"

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

    mentions_protected "$command_line" || exit 0

    # A mutating verb only matters when it shares a command with a protected
    # path — "rm /tmp/x && cat corpus-fixtures/y" must not deny on "rm" alone.
    #
    # A pipeline is deliberately NOT split: data flows along it, so
    # "echo corpus-fixtures/x | xargs rm -f" is one operation on the fixture and
    # splitting it would hide the verb from the path. Only `;`, `&&`, `||`, `&`
    # and newlines start a genuinely separate command.
    #
    # Verb boundaries admit backtick, `(` and `{` so a subshell or command
    # substitution cannot smuggle the verb past the check.
    verb_pattern='(^|[;&|`({[:space:]])(rm|mv|cp|ln|truncate|tee|dd|shred|rsync|install|sponge)([[:space:]]|$)'
    verb_pattern+='|(sed|perl)[[:space:]][^;&]*-i'
    verb_pattern+='|find[[:space:]][^;&]*-(delete|exec)'
    verb_pattern+='|>'
    verb_pattern+='|git[[:space:]]+(checkout|restore|mv|rm)([[:space:]]|$)'

    segments="${command_line//&&/$'\n'}"
    segments="${segments//||/$'\n'}"
    segments="${segments//;/$'\n'}"
    segments="${segments//&/$'\n'}"

    while IFS= read -r segment || [[ -n "$segment" ]]; do
      segment="$(strip_comment "$segment")"
      mentions_protected "$segment" || continue
      if printf '%s' "$segment" | grep -Eq "$verb_pattern"; then
        deny "$DENY_FIXTURE"
      fi
    done <<<"$segments"
    ;;
esac

exit 0
