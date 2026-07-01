# 🔧 Maintainers

How releases and CI work for this repo.

## Releases (release-please)

Releases are automated by [release-please](https://github.com/googleapis/release-please) via
`.github/workflows/release.yml`, driven by [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` → minor bump · `fix:` → patch · `feat!:` / `BREAKING CHANGE:` → minor (pre-1.0)
- `docs:` / `chore:` / `ci:` / `refactor:` → no release

On each push to `main`, release-please opens or updates a `chore: release X.Y.Z` PR that bumps the
version in three files at once (kept in sync via `release-please-config.json` `extra-files`):

- `package.json` (`version`)
- `plugins/rust-optimizer/.claude-plugin/plugin.json` (`version`)
- `.claude-plugin/marketplace.json` (`metadata.version`)

Merging that PR creates the `vX.Y.Z` tag and the GitHub Release, and regenerates `CHANGELOG.md`. **Do
not** edit versions or the changelog by hand.

### One-time setup: the RELEASE_PLEASE_TOKEN secret

If the org disables "Allow GitHub Actions to create and approve pull requests," the default
`GITHUB_TOKEN` can't open the release PR. Provide a PAT as the `RELEASE_PLEASE_TOKEN` repo secret:

- Classic token with `repo` scope, or a fine-grained token with **Contents** + **Pull requests: write**.

The workflow falls back to `GITHUB_TOKEN` if the secret is absent, so it still parses (it just won't
open the PR).

## CI

`.github/workflows/ci.yml` runs on every push/PR to `main`:

- **validate** — `node scripts/validate-manifests.mjs` (structural + version-sync check; no deps).
- **check** — `pnpm run check` (prettier + markdownlint).
- **shellcheck** — lints the skill's bash scripts (they run in users' repos, so a shell bug ships to everyone).
- **audit** — `pnpm audit --audit-level moderate`.

`link-check.yml` validates markdown links with lychee on PRs and weekly; scheduled runs open an issue
on breakage instead of failing.

## Local commands

```bash
pnpm install
pnpm run check        # validate + format:check + lint
pnpm run lint:sh      # shellcheck skill scripts
pnpm run check:all    # + offline link check
pnpm run fix          # auto-fix formatting + markdownlint
```

## Bumping the version manually (rarely needed)

Let release-please do it. If you must, update all three files above and
`.release-please-manifest.json` together, then run `node scripts/validate-manifests.mjs` to confirm
they're in sync.
