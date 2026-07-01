# Contributing

Thanks for helping improve rust-optimizer. The deliverable here is **prompt content** — a skill, its
references and scripts, and thin command wrappers. The Node tooling exists only to keep the manifests
valid and the docs lint-clean.

## Repository layout

```
.claude-plugin/marketplace.json          # marketplace manifest (lists the plugin)
plugins/rust-optimizer/
  .claude-plugin/plugin.json             # plugin manifest (version synced with marketplace)
  commands/                              # thin slash-command wrappers → delegate to the skill
  skills/optimize/
    SKILL.md                             # the discipline (lean; progressive disclosure)
    references/*.md                      # loaded only when a step needs them
    scripts/*.sh                         # portable bash: read + report, never modify a target repo
  docs/WORKFLOW.md                       # design rationale
docs/                                    # user-facing guides
scripts/validate-manifests.mjs          # CI manifest check
```

## The invariants (load-bearing — don't break these)

1. **The skill never edits code.** It audits, reports, and hands off. Editing is autopilot's job. A PR
   that makes the skill mutate a target repo's source/CI/Docker is wrong by construction.
2. **Every rule has a machine-checkable Definition of Done** in autopilot vocabulary (`cmd:` /
   `grep:` / `grep:absent:`). If you add a rule without a DoD, autopilot can't verify the fix.
3. **The compiler/runtime is the arbiter.** Findings are verified empirically, not by grep alone.
   Scripts emit _candidates_; the report only includes what a build/test/probe confirms.
4. **Account- and visibility-aware.** Runner/arch recommendations are gated (see
   `references/account-awareness.md`) and marked N/A when a repo can't use them. A hardcoded specialty
   runner label makes jobs queue forever.
5. **Metrics are honest.** Deterministic vs empirical stay separated; warm-vs-warm, never a cold-cache
   scare number; empirical numbers need enough samples or they're withheld.
6. **Scripts are read-only w.r.t. the target repo.** The only file they write is under `.optimizer/`.

## Authoring conventions

- **Skills:** frontmatter `name` (matches the directory) + a pushy, trigger-rich `description`. Keep
  `SKILL.md` lean and push detail into `references/`. Explain the _why_, not just the _what_.
- **Commands:** thin wrappers with `description` + `argument-hint`. Delegate to the skill; don't
  duplicate its logic.
- **Scripts:** `bash` with `set -euo pipefail`, shellcheck-clean, depending only on `bash`, `gh`,
  `jq`, `cargo`, `git`. Guard greps so a no-match doesn't kill the script under `pipefail`.

## Local checks

```bash
pnpm install
pnpm run check        # validate manifests + prettier + markdownlint
pnpm run lint:sh      # shellcheck the skill scripts
pnpm run check:all    # also runs the offline link check
pnpm run fix          # auto-fix formatting + markdownlint
```

CI runs the same checks plus a `pnpm audit`.

## Pull requests

We use [Conventional Commits](https://www.conventionalcommits.org/) — release-please derives the
changelog and version bumps from them (PR titles become the squash-merge commit message):

- `feat:` → minor bump · `fix:` → patch · `feat!:` / `BREAKING CHANGE:` → minor (pre-1.0)
- `docs:`, `chore:`, `ci:`, `refactor:` → no release

Do not edit `CHANGELOG.md` or bump versions by hand — release-please owns those.
