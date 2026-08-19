# Contributing

Changes reach `main` through `staging`:

```text
feature/xyz  ──PR──▶  staging  ──PR──▶  main
```

`main` is what gets installed. Both install paths in `README.md` — the w1ld0s
`modules/90-tools.sh` clone and the standalone one — clone without `--branch`,
so whatever sits on `main` lands on a fresh workstation as soon as it is
merged. `staging` is where a change proves itself first: the linters run on it,
and the operator commands can be exercised against a real target before the
branch that provisions machines moves.

That also fixes the default branch. `main` has to stay default so those clones
keep working, which means a new PR is based on `main` unless you say otherwise
— see [Opening a PR](#opening-a-pr) below.

## Branches

- `main` — installed by w1ld0s. Only `staging` and `hotfix/*` may target it.
- `staging` — integration branch. Feature work lands here first.
- `feature/xyz` — one concern per branch, branched off `staging`.
- `hotfix/xyz` — branched off `main`, for a fix that cannot wait for the next
  staging cycle. Merge it to `main`, then merge `main` back into `staging` so
  the two do not drift.

```bash
git switch staging && git pull
git switch -c feature/xyz
```

## Opening a PR

Feature branches must be retargeted, because the base defaults to `main`:

```bash
gh pr create --base staging --fill
```

Forgetting is caught rather than merged. `.github/workflows/pr-base-guard.yml`
fails any PR into `main` from a branch that is not `staging` or `hotfix/*`, and
prints the `gh pr edit --base staging` needed to fix it.

Promoting staging is the same command with the other base:

```bash
gh pr create --base main --head staging --title "Promote staging"
```

## Merging

- **Feature into staging: squash.** One commit per feature keeps `staging`
  readable and keeps a branch's work-in-progress commits out of history.
- **Staging into main: merge commit.** This is load-bearing. Squashing
  `staging` into `main` writes a new commit with no ancestry from `staging`, so
  the two branches permanently diverge and every later promotion conflicts
  against changes it already contains. A merge commit keeps `main` an ancestor
  of nothing it has not actually seen, and no back-merge is ever needed.

Rebase merging is disabled on the repository for the same reason. Merged
branches delete themselves.

## Before you push

There is no test suite, so the linters are the check. CI runs super-linter over
**changed files only**, which is worth reproducing locally rather than
discovering over several push-and-wait cycles. Pin the same configs CI uses —
they come from the SHA `.github/workflows/super-linter.yml` is pinned to:

```bash
SL=https://raw.githubusercontent.com/super-linter/super-linter/4ce20838b8ab83717e78138c5b3a1407148e0918
curl -sfLO "$SL/TEMPLATES/.markdown-lint.yml"
curl -sfLO "$SL/TEMPLATES/.yaml-lint.yml"

CHANGED=$(git diff --name-only origin/staging...HEAD)
shellcheck $(echo "$CHANGED" | grep -E '\.(sh|bash)$')
ruff check $(echo "$CHANGED" | grep '\.py$')
yamllint -c .yaml-lint.yml $(echo "$CHANGED" | grep -E '\.ya?ml$')
npx markdownlint-cli@0.45.0 --config .markdown-lint.yml $(echo "$CHANGED" | grep '\.md$')
codespell $CHANGED
```

Plus the repo's own checks, which no linter covers:

```bash
bash -n <script>                          # every shell file touched
python3 -m py_compile <script>.py
zsh -i -c exit                            # aliases must not break the shell
./setup_links -d && ./setup_links         # symlinks resolve
```

macOS ships bash 3.2 and BSD `find`; `setup_links`, `scriptlist` and `common`
use `mapfile` and `find -printf`, which are neither. A clean run on macOS proves
less than it appears to — the target is Ubuntu with bash 5. Say in the PR which
checks ran where.

## Commits and PRs

One commit per logical change; if the body needs the word "also", it is
probably two commits. Subject line is a short imperative, no trailing period,
then a blank line, then plain prose. Open with what was wrong or missing, close
with what the change does about it, and name concrete files, symbols and values
— `serve() assigned IP=$(...) without local`, not "fixed a scoping issue".

PR bodies follow `.github/pull_request_template.md`: a lede saying what the PR
is and why, bullets for what a reviewer needs that the diff does not already
show, and a closing `Verified:` paragraph naming what was actually run and what
it showed — including what was not run, and why.

## Two things that will bite you

Both are documented in `README.md` and worth repeating here.

The **executable bit decides what becomes a command**. `setup_links` symlinks
every executable file into `~/.local/bin` by basename with the extension
stripped, so `chmod +x` on a helper silently publishes it — check the basename
does not collide with something already on `PATH`. `aliases` is mode `0644` on
purpose: it is sourced, not run.

**`aliases` is sourced at every interactive shell startup**, so a failure there
breaks the shell. Guard every read, never call anything slow, interactive or
network-bound, and test with a real `zsh -i -c exit` before claiming it works.
