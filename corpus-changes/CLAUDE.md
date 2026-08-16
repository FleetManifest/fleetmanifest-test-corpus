# corpus-changes/

These 200 files are **seeded test fixtures, not work items.**

Each `corpus-pr-NNNN.md` pairs one-to-one with a remote branch `origin/corpus/pr-NNNN`. 67 of the
200 carry a `-fail` suffix on **both** the branch name and the stub filename
(`corpus/pr-0000-fail` ↔ `corpus-pr-0000-fail.md`); `.github/workflows/corpus-ci.yml` fails CI on
any branch matching `*-fail`, which is how the corpus produces a red-CI signal on demand.

## Do not

- Edit, renumber, reword, or reformat an existing stub. A `PreToolUse` hook blocks this.
- Regenerate the set, or "fix" the numbering gaps — there are none, and looking for them wastes time.
- Treat the `Derived from <sha>` line as a task. It is provenance pointing at the upstream commit a
  stub was modelled on, not an instruction to reproduce that commit.

## To add one

Use the `seeding-a-corpus-pr` skill. Creating a **new** stub here is allowed; the guard only blocks
changes to files that already exist.
