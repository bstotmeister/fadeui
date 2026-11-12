# Contributing to FadeUI

## Bugs and feature requests

Open an [issue](https://github.com/bstotmeister/fadeui/issues/new/choose) with the
Bug report or Feature request form. New issues get the `triage` label. The maintainer
removes it once the issue is confirmed, and sets a milestone if it's planned.

## Labels

| Label | Meaning |
| --- | --- |
| `enhancement` | New feature or option |
| `bug` | Something isn't working |
| `compatibility` | Support for another addon (Questie, Chattynator...) |
| `documentation` | README, CurseForge description, repo docs |
| `triage` | Needs a maintainer look |

PR labels also group the release notes (see `.github/release.yml`).

## Milestones

There's one milestone per release, named after its tag (`v1.5.0`). An issue or PR's
milestone is the release it's planned for, and no milestone means not planned yet.
When the tag ships, CI closes the milestone, so each closed milestone lists what went
into that release.

## Branches and pull requests

- Branch from an up-to-date `origin/main` (`git fetch && git switch -c my-change origin/main`), one change per branch.
- Open a PR into `main`, put `Closes #N` in the description, and set a label and milestone.
- [luacheck](https://github.com/lunarmodules/luacheck) runs on `FadeUI/` (config in `.luacheckrc`) and must pass.
- PRs are squash-merged, and the branch is deleted after the merge.

## Releasing

1. Bump `## Version` in `FadeUI/FadeUI.toc` in a `Release vX.Y.Z` PR. Merge it last,
   after everything else in the milestone.
2. Tag the squash commit on `main` and push the tag:

   ```sh
   git fetch && git tag -a vX.Y.Z -m vX.Y.Z origin/main && git push origin vX.Y.Z
   ```

   The Release workflow runs the [BigWigs packager](https://github.com/BigWigsMods/packager)
   to build `FadeUI-vX.Y.Z.zip` (dev files are excluded by `.pkgmeta`). It then creates the
   GitHub release, with notes that list the release's PRs, and closes the milestone.
3. Upload to CurseForge from your machine. CI doesn't do this. Put `CF_API_KEY=...` in a
   gitignored `.env` at the repo root, check out the tag, and run
   `/opt/homebrew/bin/bash scripts/release.sh`. It needs bash 4.3+ (`brew install bash`);
   `-d` builds without uploading.
