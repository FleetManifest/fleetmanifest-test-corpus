# Why Superpowers — Explainer Doc Design

**Date:** 2026-08-16
**Status:** Approved (design), pending implementation

## Problem

This repo explains *what* Superpowers is and *how to install it*. `README.md` covers the
quickstart, per-harness installation, the seven-step workflow, and a skills index. What it does
not do is make the case for adoption to a reader who has not yet decided they want it.

A developer evaluating Superpowers arrives skeptical. They want to know which problem it solves,
whether that problem is one they actually have, and what adopting it costs them. The README
answers none of those questions directly — it assumes the decision is already made.

## Goal

Add one new document that makes the adoption case, grounded entirely in evidence from this
checkout.

**Audience:** developers evaluating whether to adopt Superpowers. Skeptical, technically fluent,
unwilling to be sold to.

**Not upstreamed.** This is a local document. It is not intended for a PR to `obra/superpowers`,
and it is deliberately out of scope for the contribution bar in `CLAUDE.md`.

## Placement

Single new file: `docs/why-superpowers.md`.

Not a README edit. The README is install-and-reference material; this is an argument. Merging the
two would bloat the project's entry point and bury the install instructions that most readers
actually came for.

**Length:** 700–950 words (draft measures 892). Skimmable headers. No images, no diagrams.

## Structure

The document opens with one framing paragraph: a capable coding agent's characteristic failures
are not capability failures, they are discipline failures. The agent knows how to write a test; it
just doesn't, unless something makes it.

Six sections follow, each in `Failure → Mechanism → Receipt` form.

| # | Failure mode | Mechanism | Receipt |
|---|---|---|---|
| 1 | Starts coding before understanding the ask | `brainstorming` HARD-GATE | `skills/brainstorming/SKILL.md:12-14` |
| 2 | Tests written after the code, or not at all | `test-driven-development` Iron Law + Red Flags table | `skills/test-driven-development/SKILL.md:31-35`, `:228-244` |
| 3 | Claims "done" without running anything | `verification-before-completion` gate function | `skills/verification-before-completion/SKILL.md:20` |
| 4 | Debugs by guessing | `systematic-debugging` four-phase process | `skills/systematic-debugging/SKILL.md:48,120,143,168` |
| 5 | Loses the plot on long work | `writing-plans` 2–5 minute tasks; `subagent-driven-development` fresh subagent per task | `skills/writing-plans/SKILL.md:47`, `skills/subagent-driven-development/SKILL.md:12,41` |
| 6 | Reviews its own work sympathetically | Separate read-only reviewer agents scoped to the task diff | `skills/requesting-code-review/code-reviewer.md:35`, `skills/subagent-driven-development/task-reviewer-prompt.md:52` |

Section 2 is the one to write most carefully. The Red Flags table's value is that it pre-names the
rationalizations an agent reaches for — "I already manually tested it", "TDD is dogmatic, I'm being
pragmatic", "Already spent X hours, deleting is wasteful" — and answers all thirteen with the same
instruction: delete the code, start over. Quote the rationalizations directly; paraphrase loses the
effect.

### The load-bearing section

After the six failure modes: **why this is a platform and not a prompt.**

None of the above helps if the developer has to remember to invoke it. The `SessionStart` hook in
`hooks/hooks.json` matches `startup|clear|compact` and injects the `using-superpowers` bootstrap
automatically — including after compaction, which is precisely the moment a long-running agent
otherwise drifts off-process. The discipline is re-asserted at the point of maximum risk rather
than relying on the operator to notice.

This is the actual argument. The individual skills are legible as a set of good habits; the hook is
what makes them hold.

### Closing section: What it costs you

Stated plainly, not as a disclaimer:

- Slower starts — the design gate runs even on work that feels too small to need it
- Strong opinions you may not share — TDD is non-negotiable inside the skill
- More tokens per task — subagent review multiplies calls
- Process weight on trivial fixes

Plus the escape hatch: the bootstrap's own "User Instructions" section
(`skills/using-superpowers/SKILL.md`, final section) ranks user instructions (`CLAUDE.md`,
`AGENTS.md`, `GEMINI.md`, direct requests) above skills, which in turn override default behavior. A
project that says "don't use TDD" wins.

Note: the installed plugin build (superpowers-dev 5.0.2) carries a newer bootstrap with an
"Instruction Priority" numbered list saying the same thing. The doc cites this checkout's wording,
not the installed build's.

For a skeptical reader this section is not a hedge, it is the part that makes the rest credible. A
document that claims only benefits reads as marketing and gets discarded.

## Evidence rules

1. Every claim points at a file in this checkout.
2. Quote rather than paraphrase where exact wording is the point (Iron Laws, Red Flags,
   HARD-GATE).
3. No performance claims, no adoption numbers, no multiplier language.
4. No comparisons to other frameworks — they cannot be verified from this repo.
5. All line references verified against the working tree at the time of writing.

## Out of scope

- Editing `README.md`
- Install instructions (the README owns these)
- Framework comparisons
- Upstream contribution
- Any change to skill content

## Acceptance criteria

- [ ] `docs/why-superpowers.md` exists, 700–950 words
- [ ] All six failure-mode sections present, each naming a specific file
- [ ] Every quoted string matches its source file exactly
- [ ] Every file:line reference resolves in the working tree
- [ ] "Why a platform, not a prompt" section present and cites the `startup|clear|compact` matcher
- [ ] "What it costs you" section present with at least four honest costs and the "User Instructions" escape hatch
- [ ] No claim in the document lacks a corresponding file in this checkout
- [ ] No files other than `docs/why-superpowers.md` modified
