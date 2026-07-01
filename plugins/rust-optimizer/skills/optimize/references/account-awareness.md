# Account & Visibility Awareness

The same finding can be a big win on one repo and impossible on another — it depends entirely on the
GitHub **account type** and **repo visibility**. This is why Step 1 runs
`gh repo view --json visibility,isInOrganization,owner` before any runner recommendation. When a
finding can't be used, the report marks it **N/A** with the reason; it never recommends a runner label
the repo can't actually schedule.

## Runner availability matrix

| Runner                                    | Availability                             | Notes                                                                                             |
| ----------------------------------------- | ---------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `ubuntu-latest` (x64)                     | **Free, all accounts.**                  | The safe default; always a valid fallback.                                                        |
| `ubuntu-24.04-arm` (native arm64, 4 vCPU) | **Free for PUBLIC repos, all accounts.** | The native-arm64 win for Docker/release (rule D1).                                                |
| `ubuntu-24.04-arm` on **PRIVATE** repos   | **Billed, and lower spec.**              | Native arm64 reached private repos in **Jan 2026** at **2 vCPU**, billed by the minute. Not free. |
| Larger x64 runners (8/16-core)            | **Org Team/Enterprise only.**            | Unavailable to personal accounts; don't recommend for them.                                       |

## The two hard rules

1. **A nonexistent runner label queues forever.** GitHub does **not** gracefully fall back to
   `ubuntu-latest` when a label doesn't resolve — the job sits in "queued" indefinitely. So **never
   hardcode a specialty label.** Always parameterize:

   ```yaml
   runs-on: ${{ vars.HEAVY_RUNNER || 'ubuntu-latest' }}
   ```

   The repo variable can be set to `ubuntu-24.04-arm` (or a larger runner) where it's actually
   available, and everywhere else the safe default wins. This is rule C3, and it's what makes the
   arm64 recommendation (D1) safe to ship.

2. **Mark findings N/A when the account can't use them.** Examples:
   - Native-arm64 split (D1) on a **private personal repo** → **N/A / billed**: the `-arm` label is
     billed and 2 vCPU, so the "free 4 vCPU native" premise doesn't hold. Note it as "available but
     billed" rather than recommending it outright.
   - Larger x64 runner suggestion on a **personal account** → **N/A**: Team/Enterprise only.
   - Native-arm64 split on a **public repo** → **applies**: free 4 vCPU native arm64.

## Decision quick-reference

| Detected               | arm64 native split (D1)          | Larger runners            |
| ---------------------- | -------------------------------- | ------------------------- |
| Public repo, personal  | ✅ free (`ubuntu-24.04-arm`)     | ❌ (Team/Enterprise only) |
| Public repo, org       | ✅ free                          | ✅ if Team/Enterprise     |
| Private repo, personal | ⚠️ N/A — billed, 2 vCPU          | ❌                        |
| Private repo, org      | ⚠️ billed; ✅ if Team/Enterprise | ✅ if Team/Enterprise     |

Always express runner choices through `${{ vars.X || 'ubuntu-latest' }}` so the spec is portable
across all of these without editing.
