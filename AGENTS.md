# Development context for Claude Code

This repo **is** a Claude Code marketplace plugin. The product is prompt content: a skill
(`plugins/rust-optimizer/skills/optimize/`), its references and bash scripts, and three thin command
wrappers. The Node tooling only validates manifests and lints docs.

## What the plugin does

`rust-optimizer` audits a Rust repo's GitHub Actions CI, release workflow, Docker images, caching, and
dependency graph, then emits an autopilot-ready `OPTIMIZATION_SPEC.md`. It is **audit-and-report only —
it never edits a target repo's code.** Fixes ship via the separate `autopilot` plugin.

## Hard rules when working in this repo

- **Never make the skill mutate a target repo.** Audit → report → hand off. The scripts are read-only
  except for files under `.optimizer/`.
- **Every rule needs a machine-checkable DoD** in autopilot vocabulary (`cmd:` / `grep:` /
  `grep:absent:`). See `references/spec-template.md` and `references/rule-catalog.md`.
- **Verify empirically.** The compiler/test/probe is the arbiter; grep hits are hypotheses.
- **Keep manifests in sync.** `.claude-plugin/marketplace.json` `metadata.version`,
  `plugins/rust-optimizer/.claude-plugin/plugin.json` `version`, and `package.json` `version` must
  match — release-please maintains this. Run `node scripts/validate-manifests.mjs` after changes.
- **Scripts:** `set -euo pipefail`, shellcheck-clean. Guard greps (`{ grep … || true; } | wc -l`) so a
  no-match doesn't abort under `pipefail`.

## Before committing

```bash
pnpm run check        # manifests + prettier + markdownlint
pnpm run lint:sh      # shellcheck skill scripts
```

## Conventions

- Conventional Commits (release-please + changelog automation). Don't edit `CHANGELOG.md` by hand.
- Progressive disclosure: `SKILL.md` stays lean; depth lives in `references/`.
- Don't add a `Co-Authored-By` trailer unless the repo's settings opt in.
