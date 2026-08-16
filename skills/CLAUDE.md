# skills/

The 14 Superpowers plugin skills. These are behaviour-shaping content, closer to code than to prose:
they are tuned against real agent sessions, and small wording changes measurably change what agents do.

## Rules

- **Frontmatter is exactly `name` and `description`.** Nothing else. `description` is the trigger
  text — it is what a model matches against when deciding to invoke the skill, so it describes
  *when to use this*, not what it contains.
- **"Your human partner" is deliberate.** It is not interchangeable with "the user". Do not
  normalise it.
- **Do not reformat to Anthropic's published skill-authoring guidance.** This project's conventions
  diverge from it on purpose.
- **Do not soften the rigid skills.** Red Flags tables, rationalization lists, and Iron Law framings
  in `test-driven-development`, `systematic-debugging`, and `verification-before-completion` are the
  load-bearing parts. They pre-name the excuses an agent reaches for; paraphrasing removes the effect.
- **Behavioural changes need evidence.** Use `superpowers:writing-skills` to develop and test a
  change. Eval scenarios live in the separate `superpowers-evals` repo, cloned into a gitignored
  `evals/` (absent from this checkout).

## Related surfaces

`.codex-plugin/plugin.json` and `.claude-plugin/plugin.json` are committed plugin manifests.
`scripts/sync-to-codex-plugin.sh` pushes this whole checkout to an external fork
(`prime-radiant-inc/openai-codex-plugins`) and opens a PR there — it is a release step, not
something to run after an edit. `scripts/package-codex-plugin.sh` builds the portal archive.
