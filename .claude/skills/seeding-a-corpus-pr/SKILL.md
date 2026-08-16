---
name: seeding-a-corpus-pr
description: Use when adding a new seeded corpus PR to this repo - covers branch naming, the -fail convention, and the paired stub file
---

# Seeding a Corpus PR

A corpus entry is a **pair**: a remote branch and a stub file. Both must exist, and their names must
agree. There are 200 such pairs; 67 carry a `-fail` suffix.

## The pair

| Part | Form | Example |
|---|---|---|
| Branch | `corpus/pr-NNNN` | `corpus/pr-0042` |
| Stub | `corpus-changes/corpus-pr-NNNN.md` | `corpus-changes/corpus-pr-0042.md` |

`NNNN` is zero-padded to four digits. To arm a CI failure, append `-fail` to **both**:
`corpus/pr-0042-fail` and `corpus-changes/corpus-pr-0042-fail.md`.
`.github/workflows/corpus-ci.yml` matches `*-fail` on `github.head_ref` and exits 1.

A mismatched pair — `-fail` on one side only — produces a branch whose CI outcome disagrees with its
stub. That is the single most common way to corrupt the corpus.

## Stub format

Three parts, blank-line separated:

```markdown
# <type>: <subject>

Derived from <full 40-char sha>.

Corpus entry <N>.
```

`<type>: <subject>` reads like a commit subject (`docs:`, `chore:`, `fix:`). The `Derived from` sha
is the upstream commit the entry was modelled on — provenance only. `<N>` is the integer form of
`NNNN` without padding.

## Steps

1. Pick the next free `NNNN`: `ls corpus-changes/ | tail -1`.
2. Decide whether it fails. If so, both names take `-fail`.
3. Create the stub. Creating a **new** file under `corpus-changes/` is permitted by the guard hook;
   editing an existing one is not.
4. Branch, commit, push: `git switch -c corpus/pr-NNNN[-fail]`.
5. Confirm the pair agrees before opening the PR.

## Do not

- Renumber, reword, or reformat existing stubs. They are fixtures.
- Create a stub without its branch, or a branch without its stub.
