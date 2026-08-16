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
