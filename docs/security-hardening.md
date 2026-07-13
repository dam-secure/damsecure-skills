# Security hardening: open-source repo, employee-only contribution

This repo is **public** (open source) but only **Dam Secure employees** may
contribute. Because customers install and execute what lands on `main`, the goal
is supply-chain integrity: anyone can read/fork, nobody outside the company can
change what ships.

GitHub can't literally block "non-employees" — it gates on **write access**.
The model: keep write access to employees only, and make `main` unwritable
except through reviewed PRs. Forks + PRs from outsiders are allowed (that's how
open source works) but **cannot merge**.

## Layered controls

### 1. Access (who holds write) — org-level
- Write access granted **only** through the org to an employee team; never add
  individual outside collaborators.
- Org base permission for the repo should be **Read** (or None), so merely being
  an org member doesn't grant write — write comes from explicit team membership.

### 2. Branch protection on `main` — repo-level (applied here)
- Require a pull request before merging.
- Require **≥1 approving review** and **review from Code Owners**
  ([`.github/CODEOWNERS`](../.github/CODEOWNERS)).
- Dismiss stale approvals on new commits.
- Require the **`validate` status check** to pass.
- Require conversation resolution and linear history.
- **Block force-pushes and deletions**; no bypass actors.

### 3. Contribution hygiene
- `CODEOWNERS` forces an employee reviewer on every change.
- `CONTRIBUTING.md` states the employee-only policy explicitly.
- Fork PRs run CI only after **maintainer approval** (`fork_pr_workflows_policy`),
  so untrusted code can't execute in Actions automatically.

### 4. Actions / CI supply chain — repo-level (applied here)
- Default `GITHUB_TOKEN` permissions set to **read-only**.
- Workflow declares `permissions: contents: read` explicitly.
- CI uses only first-party `actions/checkout`; Dependabot keeps it patched
  ([`.github/dependabot.yml`](../.github/dependabot.yml)).

### 5. Detection — repo-level (applied here)
- **Secret scanning** + **push protection** on (blocks committed credentials).
- **Dependabot alerts** on.
- Private vulnerability reporting on ([`SECURITY.md`](../SECURITY.md)).

## What was applied automatically vs. needs an org owner

| Control | Applied by setup | Needs org owner |
|---|---|---|
| Repo created public in `dam-secure` | ✅ | |
| Branch ruleset on `main` (PR, review, code-owner, CI, no force-push/delete) | ✅ | |
| Secret scanning + push protection | ✅ | |
| Dependabot alerts | ✅ | |
| Read-only default workflow token + fork-PR approval | ✅ | |
| Private vulnerability reporting | ✅ | |
| Create/assign the **employee team** with write access | | ⛔ requires `admin:org` |
| Set org **base permission = Read** | | ⛔ requires `admin:org` |
| Swap `CODEOWNERS` from the individual maintainer to the employee team | | ⛔ after team exists |
| Require **signed commits** (optional, recommended) | | ⛔ org policy / ruleset toggle |

The setup user is an org **member without `admin:org`**, so the org-level rows
must be completed by an org owner. Until the employee team exists, `CODEOWNERS`
points at the individual maintainer (still a valid employee-only gate).
