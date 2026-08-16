# Why-Superpowers Explainer Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `docs/why-superpowers.md`, a 700–900 word explainer that makes the adoption case to a skeptical developer, with every claim traceable to a file in this checkout.

**Architecture:** One new Markdown file, built in three passes (framing + failure modes 1–3, failure modes 4–6, closing sections). Correctness is enforced by a scratchpad shell script that verifies every quoted string appears verbatim in BOTH its source file and the doc, plus word count and working-tree cleanliness. The script is written first and must fail before the doc exists.

**Tech Stack:** Markdown, bash, grep, git. No dependencies — this repo is zero-dependency by design.

**Spec:** `docs/superpowers/specs/2026-08-16-why-superpowers-explainer-design.md`

**Branch:** `docs/why-superpowers-explainer` (already created)

---

## Chunk 1: Explainer document

### Task 1: Acceptance-check script (RED)

The "test" for a prose deliverable is that every quote is verbatim and every receipt resolves. Write the checker first and watch it fail.

**Files:**
- Create: `/private/tmp/claude-501/-Users-glynrob-corpus/c77ae3f8-5b87-4332-bf61-ae3cec4caca7/scratchpad/check-doc.sh`

Note: the script lives in the scratchpad, NOT the repo. The spec requires that no file other than `docs/why-superpowers.md` be added or modified.

- [ ] **Step 1: Write the failing check**

```bash
#!/usr/bin/env bash
# Acceptance checks for docs/why-superpowers.md
set -uo pipefail
cd /Users/glynrob/corpus || exit 1

DOC="docs/why-superpowers.md"
fails=0
pass() { printf '  ok   %s\n' "$1"; }
fail() { printf '  FAIL %s\n' "$1"; fails=$((fails+1)); }

check_file() { # <label> <literal> <file>
  if grep -Fq -- "$2" "$3" 2>/dev/null; then pass "$1"; else fail "$1"; fi
}

echo "== doc exists =="
if [ -f "$DOC" ]; then pass "$DOC present"; else fail "$DOC present"; fi

echo "== quotes verbatim in SOURCE files =="
check_file "src: brainstorming HARD-GATE" \
  "Do NOT invoke any implementation skill, write any code, scaffold any project, or take any implementation action until you have presented a design and the user has approved it." \
  skills/brainstorming/SKILL.md
check_file "src: TDD iron law" \
  "NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST" \
  skills/test-driven-development/SKILL.md
check_file "src: TDD delete/start over" \
  "Write code before the test? Delete it. Start over." \
  skills/test-driven-development/SKILL.md
check_file "src: TDD red flag verdict" \
  "All of these mean: Delete code. Start over with TDD." \
  skills/test-driven-development/SKILL.md
check_file "src: verification iron law" \
  "If you haven't run the verification command in this message, you cannot claim it passes." \
  skills/verification-before-completion/SKILL.md
check_file "src: verification skip=lying" \
  "Skip any step = lying, not verifying" \
  skills/verification-before-completion/SKILL.md
check_file "src: writing-plans zero context" \
  "zero context for our codebase and questionable taste" \
  skills/writing-plans/SKILL.md
check_file "src: sdd no context pollution" \
  "Fresh subagent per task (no context pollution)" \
  skills/subagent-driven-development/SKILL.md
check_file "src: reviewer read-only" \
  "Your review is read-only on this checkout. Do not mutate the working tree, the index, HEAD, or branch state in any way." \
  skills/requesting-code-review/code-reviewer.md
check_file "src: hook matcher" \
  "startup|clear|compact" \
  hooks/hooks.json
check_file "src: user instructions precedence" \
  "take precedence over skills, which in turn override default behavior" \
  skills/using-superpowers/SKILL.md

echo "== same quotes present in DOC =="
for q in \
  "Do NOT invoke any implementation skill" \
  "NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST" \
  "Write code before the test? Delete it. Start over." \
  "All of these mean: Delete code. Start over with TDD." \
  "If you haven't run the verification command in this message, you cannot claim it passes." \
  "Skip any step = lying, not verifying" \
  "zero context for our codebase and questionable taste" \
  "no context pollution" \
  "Your review is read-only on this checkout" \
  "startup|clear|compact" \
  "take precedence over skills"; do
  check_file "doc: ${q:0:46}" "$q" "$DOC"
done

echo "== referenced files exist =="
for f in skills/brainstorming/SKILL.md skills/test-driven-development/SKILL.md \
         skills/verification-before-completion/SKILL.md skills/systematic-debugging/SKILL.md \
         skills/writing-plans/SKILL.md skills/subagent-driven-development/SKILL.md \
         skills/requesting-code-review/code-reviewer.md \
         skills/subagent-driven-development/task-reviewer-prompt.md \
         skills/brainstorming/spec-document-reviewer-prompt.md \
         skills/using-superpowers/SKILL.md hooks/hooks.json; do
  if [ -f "$f" ]; then pass "exists: $f"; else fail "exists: $f"; fi
done

echo "== structure =="
for h in \
  "## It starts coding before it understands the ask" \
  "## Tests get written after the code, or not at all" \
  "## It says \"done\" without running anything" \
  "## It debugs by guessing" \
  "## It loses the plot on long work" \
  "## It reviews its own work sympathetically" \
  "## Why this is a platform, not a prompt" \
  "## What it costs you"; do
  check_file "heading: ${h:3:44}" "$h" "$DOC"
done

echo "== debugging phases named =="
for p in "Root Cause Investigation" "Pattern Analysis" "Hypothesis and Testing"; do
  check_file "src phase: $p" "$p" skills/systematic-debugging/SKILL.md
  check_file "doc phase: $p" "$p" "$DOC"
done

echo "== word count 700-900 =="
if [ -f "$DOC" ]; then
  wc_words=$(wc -w < "$DOC" | tr -d ' ')
  if [ "$wc_words" -ge 700 ] && [ "$wc_words" -le 900 ]; then
    pass "word count = $wc_words"
  else
    fail "word count = $wc_words (want 700-900)"
  fi
else
  fail "word count (no doc)"
fi

echo "== no other repo files touched =="
dirty=$(git status --porcelain -- . ':!.fleetmanifest' ':!.github/workflows/fleetmanifest.yml' \
        | grep -v 'docs/why-superpowers.md' | grep -v 'docs/superpowers/' || true)
if [ -z "$dirty" ]; then pass "working tree scoped"; else fail "unexpected changes: $dirty"; fi

echo
if [ "$fails" -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "$fails CHECK(S) FAILED"; exit 1; fi
```

- [ ] **Step 2: Run it to verify it fails**

```bash
SP=/private/tmp/claude-501/-Users-glynrob-corpus/c77ae3f8-5b87-4332-bf61-ae3cec4caca7/scratchpad
chmod +x "$SP/check-doc.sh" && "$SP/check-doc.sh"
```

Expected: exits 1. All `src:` and `exists:` checks pass (source files are already there); every `doc:`, `heading:`, and word-count check FAILS because `docs/why-superpowers.md` does not exist yet.

If any `src:` check fails, STOP — a quote in this plan does not match the checkout. Fix the plan's quote to match the source file before writing any prose.

---

### Task 2: Framing and failure modes 1–3

**Files:**
- Create: `docs/why-superpowers.md`

- [ ] **Step 1: Write the opening and first three sections**

````markdown
# Why Superpowers

A modern coding agent can write a correct test, trace a race condition, and refactor a module it has never seen. Watch one work unsupervised for an hour, though, and the failures that turn up are rarely capability failures. It writes code before it understands the request. It adds tests afterward, if at all. It announces success without running anything. Those are discipline failures, and model capability does not fix them — the agent could always have done the right thing. Nothing required it to.

Superpowers is a set of skills that require it. Here is what each one is actually for.

## It starts coding before it understands the ask

Ask for a feature and the default behavior is to start producing files. The `brainstorming` skill blocks that path with a hard gate:

> Do NOT invoke any implementation skill, write any code, scaffold any project, or take any implementation action until you have presented a design and the user has approved it. This applies to EVERY project regardless of perceived simplicity.

That last sentence is load-bearing. The skill anticipates the agent's own excuse and follows the gate with a section headed "This Is Too Simple To Need A Design" to close it off.

## Tests get written after the code, or not at all

`test-driven-development` states one rule — "NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST" — and one consequence: "Write code before the test? Delete it. Start over."

What makes it hold is the Red Flags table: thirteen rows of the specific rationalizations an agent reaches for when it wants out. Among them, verbatim — "I already manually tested it", "Tests after achieve the same purpose", "It's about spirit not ritual", "Already spent X hours, deleting is wasteful", "TDD is dogmatic, I'm being pragmatic", and "This is different because...".

All thirteen get one answer: "All of these mean: Delete code. Start over with TDD."

That is the design move worth stealing. A rule an agent can argue with is a rule it will argue with. Naming the arguments in advance and refusing them removes the negotiation.

## It says "done" without running anything

`verification-before-completion` reduces to a single sentence:

> If you haven't run the verification command in this message, you cannot claim it passes.

Not "in this session" — in this message. Remembering that the suite passed earlier does not count. The skill's gate function ends: "Skip any step = lying, not verifying".
````

- [ ] **Step 2: Run the checker**

```bash
SP=/private/tmp/claude-501/-Users-glynrob-corpus/c77ae3f8-5b87-4332-bf61-ae3cec4caca7/scratchpad
"$SP/check-doc.sh"
```

Expected: still exits 1, but the first three `heading:` checks and the quote checks for sections 1–3 now pass. Word count still under 700.

- [ ] **Step 3: Commit**

```bash
git add docs/why-superpowers.md
git commit -m "docs: why-superpowers framing and first three failure modes"
```

---

### Task 3: Failure modes 4–6

**Files:**
- Modify: `docs/why-superpowers.md` (append)

- [ ] **Step 1: Append the next three sections**

````markdown
## It debugs by guessing

Handed a failing test, the default move is to change something plausible and re-run. `systematic-debugging` imposes four ordered phases — Root Cause Investigation, Pattern Analysis, Hypothesis and Testing, then Implementation. The fix comes last. You do not get to propose a change until you can say what is broken and why.

## It loses the plot on long work

Two mechanisms. `writing-plans` requires every step to be one action of two to five minutes, with exact file paths and complete code, written for an engineer assumed to have "zero context for our codebase and questionable taste". `subagent-driven-development` then dispatches a fresh subagent per task — "no context pollution" — so no single context window carries the whole job.

Long tasks degrade because context degrades. Keeping each unit small enough to hold at once is the countermeasure.

## It reviews its own work sympathetically

An agent grading its own diff finds it good. Superpowers routes review to separate agents with their own prompt files — `code-reviewer.md`, `task-reviewer-prompt.md`, `spec-document-reviewer-prompt.md` — scoped to the task diff and explicitly read-only:

> Your review is read-only on this checkout. Do not mutate the working tree, the index, HEAD, or branch state in any way.

A reviewer that cannot quietly fix what it finds has to report it.
````

- [ ] **Step 2: Run the checker**

```bash
SP=/private/tmp/claude-501/-Users-glynrob-corpus/c77ae3f8-5b87-4332-bf61-ae3cec4caca7/scratchpad
"$SP/check-doc.sh"
```

Expected: exits 1; only the final two headings and word count outstanding.

- [ ] **Step 3: Commit**

```bash
git add docs/why-superpowers.md
git commit -m "docs: why-superpowers failure modes four through six"
```

---

### Task 4: Closing sections (GREEN)

**Files:**
- Modify: `docs/why-superpowers.md` (append)

- [ ] **Step 1: Append the argument and the costs**

````markdown
## Why this is a platform, not a prompt

Everything above is a set of good habits, and you could paste them into a `CLAUDE.md` yourself. Most people do, once. Then it stops working, because applying them depends on the agent remembering to — and it doesn't.

The mechanism that makes this stick is small enough to miss. `hooks/hooks.json` registers a `SessionStart` hook with the matcher `startup|clear|compact`, which injects the bootstrap automatically at three moments: session start, after `/clear`, and after compaction.

The third one carries the weight. Compaction is exactly when a long-running agent loses the thread and reverts to default behavior, and it is the moment the discipline gets re-asserted — without anyone having to notice it was needed.

## What it costs you

It is slower to start. The design gate runs on work that genuinely is too small to need it, and you will answer questions about one-file changes.

It is opinionated in ways you may not share. TDD is not a setting here. If you do not want to work that way, most of the value leaves with it.

It costs more tokens. Fresh subagents per task and multi-stage review multiply calls against work one context could have finished.

It is heavy on trivial fixes. A typo does not need a spec, a plan, and two reviewers.

The escape hatch is documented in the bootstrap itself: user instructions — `CLAUDE.md`, `AGENTS.md`, direct requests — take precedence over skills, which in turn override default behavior. A project that says "don't use TDD" wins. Superpowers is a default, not a cage.
````

- [ ] **Step 2: Run the checker — expect green**

```bash
SP=/private/tmp/claude-501/-Users-glynrob-corpus/c77ae3f8-5b87-4332-bf61-ae3cec4caca7/scratchpad
"$SP/check-doc.sh"
```

Expected: `ALL CHECKS PASSED`, exit 0.

If word count falls outside 700–900, adjust prose in the "What it costs you" section only — the quoted material in earlier sections must not be trimmed, since the checker matches it verbatim.

- [ ] **Step 3: Commit**

```bash
git add docs/why-superpowers.md
git commit -m "docs: why-superpowers platform argument and honest costs"
```

---

### Task 5: Final verification

- [ ] **Step 1: Re-run the full checker from a clean shell**

```bash
SP=/private/tmp/claude-501/-Users-glynrob-corpus/c77ae3f8-5b87-4332-bf61-ae3cec4caca7/scratchpad
"$SP/check-doc.sh"; echo "exit=$?"
```

Expected: `ALL CHECKS PASSED` and `exit=0`.

- [ ] **Step 2: Confirm scope — only the intended file was added**

```bash
git diff --stat main...HEAD -- . ':!docs/superpowers'
```

Expected: exactly one file, `docs/why-superpowers.md`.

- [ ] **Step 3: Read the doc end to end**

Read `docs/why-superpowers.md` in full. The checker proves quotes are verbatim and structure is present; it cannot judge whether the argument reads well. Confirm it flows and that no sentence makes a claim without a file behind it.

Per superpowers:verification-before-completion, do not report this plan complete without the checker output above in the same message as the claim.

---

## Notes for the implementer

- **Do not edit `README.md`.** The spec puts it out of scope; the checker will flag it.
- **Quotes are verbatim or the build breaks.** Every `>` blockquote and every double-quoted fragment was copied from the checkout and is grep-matched by the checker. Rewording them is the one change guaranteed to fail.
- **The word budget is tight.** Roughly 885 words as drafted, against a 900 ceiling. Additions need matching cuts.
- **No new claims.** If you want to assert something the draft does not, find the file that supports it first, add it to the checker, then write the sentence.
