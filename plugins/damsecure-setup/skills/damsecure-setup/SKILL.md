---
name: damsecure-setup
description: Use when a user wants to set up, onboard, connect, or start using Dam Secure in their repo: installing the damsecure CLI, connecting the MCP server (Secure Spec plan review), onboarding a repository, reviewing or adding security rules, or triaging PR and issue findings.
---

# Dam Secure Setup

## Overview

Guides a user end-to-end onto Dam Secure, from a cold start to triaging real findings. There are three phases:

1. **Connect** (Steps 1 to 5): install the `damsecure` CLI and connect the MCP server. This also wires up **Secure Spec**, which reviews your implementation **plans** for security issues before you write code (via editor hooks + the `review_plan` MCP tool).
2. **Configure** (Parts A and B): onboard a repository so Dam Secure can scan it, then review the rules we create for you and add your own.
3. **Use** (Part C): the recurring loop, triaging findings on a pull request and working down your outstanding issues.

Phases 2 and 3 are driven through the same `damsecure` MCP server you connect in phase 1. **Connect first** (the MCP tools do not exist until then), then move through Configure and Use. The Use flows are re-entrant: once connected, a user can jump straight to "triage my PR" or "triage open issues" without repeating setup.

This skill works in **Claude Code and Cursor**. The flow is identical; only two steps differ per editor (post-install reload in Step 2, MCP auth in Step 4). Detect which editor you're running in and follow the matching row in those steps.

Official reference: https://docs.damsecure.ai/secure-spec/installation

## Quick Reference

| Thing | Value |
|-------|-------|
| Install command | `curl -fsSL https://app.damsecure.ai/resources/cli/install.sh \| bash` |
| Setup (run by installer) | `damsecure setup` (auto-detects your editors) |
| Set plans directory | `damsecure plan-dirs set <dir>` |
| Plans config file | `~/.damsecure/config.json` (`planDirs` key) |
| MCP server | `damsecure` → `https://api.damsecure.ai/mcp` (HTTP, OAuth) |
| Plan-review tool | `review_plan` (fires automatically when you save a plan) |
| Dam Secure app | `https://app.damsecure.ai` (repositories, rules, issues) |

All MCP tools below are invoked as `mcp__damsecure__<tool>` in Claude Code (e.g. `mcp__damsecure__list_issues`); Cursor exposes them under the `damsecure` server.

---

# Phase 1: Connect (Steps 1 to 5)

Run these five steps **in order**. Each gates the next: the CLI must be installed before plans can be configured, and the plugin must be loaded before the MCP server can authenticate. Do not skip ahead or batch steps.

## Step 1: Preview and find where plans already live (read-only)

First tell the user what the next four steps will do (install CLI, set plans directory, connect MCP), and that they'll authenticate **twice** in a browser: once for the CLI, once for the MCP server. Nothing is installed yet.

Then find where plans already live in the repo, following the brief in `discover-plans.md` (in this skill's directory). If your editor supports subagents (e.g. Claude Code), dispatch one so the file listing doesn't flood the main context; otherwise do it inline but keep only the ranked summary, not the raw listing. Report the ranked candidate directories to the user. Do not set anything yet; Step 3 persists the choice after the CLI exists.

## Step 2: Install the CLI

The installer runs `curl … | bash`, which downloads the `damsecure` binary and runs `damsecure setup`, which opens a browser for CLI OAuth and installs the Secure Spec plugin/extension (hooks + MCP config) into every editor it detects.

Because this is `curl | bash` and modifies the user's editor config, **show the exact command and get explicit confirmation before running it**:

```bash
curl -fsSL https://app.damsecure.ai/resources/cli/install.sh | bash
```

If the user prefers, they can run it themselves in a terminal instead. Then reload so the new plugin/MCP registers, per your editor:

| Editor | Reload step |
|--------|-------------|
| Claude Code | run `/reload-plugins` (or restart Claude Code) |
| Cursor | open MCP settings and enable/refresh the `damsecure` server (or reload the window) |

## Step 3: Confirm and set the plans directory

Present the candidate(s) from Step 1 and ask the user to confirm one (or supply their own repo-relative path, e.g. `docs/plans`, `specs`, `docs/superpowers/plans`). Then persist it:

```bash
damsecure plan-dirs set <confirmed-dir>
```

Verify with `damsecure plan-dirs list`. This writes `planDirs` to `~/.damsecure/config.json`; from then on, only plans saved under a configured directory are reviewed.

If Step 1 found no plausible plans directory, tell the user Secure Spec falls back to built-in detection (`specs/`, `plans/`, `rfcs/`, `proposals/`, `docs/plans/`, `.claude/plans/`, and `*.plan.md` files) and let them either accept that or set an explicit directory.

## Step 4: Connect the MCP server (trigger auth)

The `damsecure` MCP server is registered but not yet authenticated. This is a **separate** OAuth from the CLI login in Step 2 (MCP auth is per-editor). Trigger it per your editor:

| Editor | Trigger auth |
|--------|-------------|
| Claude Code | invoke the `mcp__damsecure__authenticate` tool directly to force the prompt. Fallback: `/mcp` → **damsecure** → Enter → **Authenticate** |
| Cursor | Settings → **MCP** → **damsecure** → **Connect** / **Login** → complete OAuth |

Complete the browser sign-in when prompted. If the server or auth tool isn't visible yet, the user hasn't reloaded since Step 2; do the reload for their editor and retry.

## Step 5: Verify

Confirm the connection works by invoking a lightweight read-only MCP tool, e.g. `list_rules` (in Claude Code: `mcp__damsecure__list_rules`). If it returns without an auth error, the connection is live.

Tell the user two things happen next, then continue to Phase 2:

- **Secure Spec is now active.** When they save an implementation plan under the configured directory, `review_plan` runs automatically and surfaces security concerns before they build.
- **They can now configure scanning.** Offer to continue into Phase 2 to onboard a repository and review rules. If they'd rather stop here, that's fine; the Use flows (Part C) work whenever they come back.

---

# Phase 2: Configure

## Part A: Onboard a repository

Check what is already connected with `list_repositories` (no arguments; it is org-scoped). Two cases:

- **Repositories already listed.** Report them (name + latest commit) and move on to Part B. Nothing to onboard.
- **Empty list.** The repository still needs to be connected. **Onboarding is not an MCP action**; it happens in the Dam Secure app via the GitHub App. Direct the user to `https://app.damsecure.ai/repositories` and have them connect the repo through the "add / connect repository" flow (this installs or grants the GitHub App on that repo). Wait for them to confirm, then call `list_repositories` again to verify the repo now appears. Scans kick off automatically once the repo is connected and commits arrive; there is no manual scan-trigger tool.

Keep the repo `id` from `list_repositories`; it is the `repositoryId` used to filter issues and rules later.

## Part B: Review and add rules

Rules are what Dam Secure scans your code for. The goal here is to give the user a quick read on their coverage, then offer to extend it.

**Report what exists.** If the repo appeared in Part A, call `list_rules` and give the user a short summary — just two facts:

- **How many rules** are active for the repo.
- **Which categories** those rules fall into (and roughly how many per category).

Keep it to that count-and-categories summary; the point is to show the *shape* of their coverage, not to read every rule line by line. If Part A came back empty (no repo connected yet), say so — nothing is scanning until the repo is onboarded — and move on to finish Phase 2.

**Add a custom rule** for anything specific to their codebase. Create one with `create_rule`:

- Required: `rule` (short name), `ruleDetails` (the prompt/what to look for), `category`.
- Optional: `severity` (`critical`/`high`/`medium`/`low`/`info`, default `medium`), `rationale`, `cwe`, `status` (`disabled`/`draft`/`live`, default `live`).

To scope a rule to specific projects, use `enable_rule_for_project` / `disable_rule_for_project` (project ids come from `get_all_projects_by_repo` or `get_projects_for_rule`). Use `update_rule` to revise an existing rule (it creates a new version under the same `ruleId`).

---

# Phase 3: Use (recurring triage)

This is the day-to-day loop, and the skill's job here is mostly to **orient the user**. For each of the two flows below, explain three things — *what it is*, *where to find it*, and *how to configure it* — then hand off to `triage.md` (in this skill's directory) for the actual step-by-step. Both flows are re-entrant; a user can invoke either one on its own once connected.

## Part C1: The PR CI check and its findings

**What it is.** When a user opens a pull request (open, not draft), the Dam Secure GitHub App runs a CI check on that branch and records any findings against it. The check is a GitHub construct — there is no PR or CI-check object over MCP — so what you actually work with are the *findings it produced*, scoped by the PR's branch name.

**Where to find it.**
- *The check itself* lives on GitHub: the PR's **Checks** / status section shows the Dam Secure run and its pass/fail state.
- *The findings* are surfaced two ways — in the Dam Secure app, and over MCP via `list_issues branch=<branch>`, which scopes to the latest scan on that branch and exposes a "ready-for-review" count.

**How to configure it.** The check is wired up by connecting the repo's GitHub App in Part A; there is no MCP toggle for it, and scans run automatically on push/PR (no manual scan-trigger tool). Its behavior — which rules run, severity gating, whether it blocks merge — is configured in the Dam Secure app under the repository's settings.

**To triage the findings**, follow Flow C1 in `triage.md` (branch → `list_issues` → `get_issue` → `confirm_finding` / `dismiss_finding` / `fix_finding`).

## Part C2: Outstanding issues

**What it is.** The standing backlog of open issues across all scans, independent of any single PR — the set you work down over time.

**Where to find it.**
- *Bulk* view in the Dam Secure app: `https://app.damsecure.ai/issues`.
- *Focused* over MCP via `list_issues status=open`.

**How to configure / focus it.** Narrow with filters — `severity`, `repositoryId`, `ruleId` — and respect pagination (`pageSize` max 100). For a large backlog, use the app's bulk view rather than grinding through hundreds of issues over MCP in one conversation.

**To triage**, follow Flow C2 in `triage.md`.

---

## Common Mistakes

- **Using MCP tools before connecting.** The `damsecure` MCP tools (`list_repositories`, `list_rules`, `list_issues`, …) do not exist until Phase 1 finishes and the editor has reloaded. Connect first.
- **Setting plan-dirs before installing the CLI.** `damsecure plan-dirs set` doesn't exist until Step 2 completes. Keep the order.
- **Expecting one login.** There are two OAuth flows: CLI (Step 2) and MCP (Step 4). Tell the user up front so the second prompt isn't a surprise.
- **Trying to onboard a repo via MCP.** There is no onboarding tool; repositories are connected in the app via the GitHub App. MCP only detects (`list_repositories`) and, later, triages.
- **Looking for a "CI check" or "scan" tool.** Neither exists. The GitHub check lives on GitHub; scans run automatically on push/PR. You triage the resulting issues/findings, scoped by branch.
- **Trying to create built-in rules over MCP.** `create_rule` makes your own custom rules only; the managed ruleset Dam Secure maintains is not created or edited over MCP.
- **Reaching for internal tooling.** Do not tell customers to run `ds:triage` or `validate-findings`; those are Dam Secure's own repo skills, not part of this plugin. Use the MCP triage tools and the app's bulk view.
- **Skipping the editor row.** Steps 2 and 4 differ by editor; follow the row for the editor you're actually running in, not the Claude Code one by default.
- **Auto-running `curl | bash`.** Always show the command and confirm first; never pipe-to-bash silently.
