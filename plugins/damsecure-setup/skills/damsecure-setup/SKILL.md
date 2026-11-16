---
name: damsecure-setup
description: Use when a user wants to set up, onboard, connect, or start using Dam Secure in their repo: connecting the Dam Secure MCP server, onboarding a repository, checking what Dam Secure scans for, or triaging PR and issue findings.
---

# Dam Secure Setup

## Overview

Guides a user end-to-end onto Dam Secure, from a cold start to triaging real findings. There are three phases:

1. **Connect** (Steps 1 to 3): add the `damsecure` MCP server to the editor, authenticate, and verify the connection.
2. **Configure** (Parts A and B): onboard a repository so Dam Secure can scan it, then confirm pull request scans are on.
3. **Use** (Part C): the recurring loop, triaging findings on a pull request and working down your outstanding issues.

Phases 2 and 3 are driven through the same `damsecure` MCP server you connect in phase 1. **Connect first** (the MCP tools do not exist until then), then move through Configure and Use. The Use flows are re-entrant: once connected, a user can jump straight to "triage my PR" or "triage open issues" without repeating setup.

This skill works in **Claude Code and Cursor**. The flow is identical; only the two connect steps differ per editor. Detect which editor you're running in and follow the matching row in those steps.

Official reference: https://docs.damsecure.ai/mcp/installation

## Quick Reference

| Thing | Value |
|-------|-------|
| MCP server | `damsecure` → `https://api.damsecure.ai/mcp` (HTTP, OAuth) |
| OAuth callback port | `6843` |
| Dam Secure app | `https://app.damsecure.ai` (repositories, rules, issues) |

All MCP tools below are invoked as `mcp__damsecure__<tool>` in Claude Code (e.g. `mcp__damsecure__list_issues`); Cursor exposes them under the `damsecure` server.

---

# Phase 1: Connect (Steps 1 to 3)

Run these three steps **in order**. The server must be added before it can authenticate, and it must authenticate before any tool call works.

## Step 1: Add the MCP server

First check whether a `damsecure` MCP server is already configured. If it is, skip to Step 2.

Otherwise add it for the user's editor. This changes their editor config, so **show the exact change and get confirmation before making it**.

| Editor | Add the server |
|--------|----------------|
| Claude Code | `claude mcp add --transport http --scope project damsecure https://api.damsecure.ai/mcp --callback-port 6843` (use `--scope user` to make it available in every project). Then restart Claude Code in the same folder so the server loads. |
| Cursor | Add the server to `.cursor/mcp.json` (this project) or `~/.cursor/mcp.json` (every project), shown below. Then open **Cursor Settings → MCP** and make sure `damsecure` is enabled. |

```json
{
  "mcpServers": {
    "damsecure": {
      "type": "http",
      "url": "https://api.damsecure.ai/mcp",
      "oauth": {
        "callbackPort": 6843
      }
    }
  }
}
```

If the user would rather do it themselves, point them at https://docs.damsecure.ai/mcp/installation, which also covers VS Code and Codex.

## Step 2: Authenticate

The server is registered but not yet signed in. Trigger the browser OAuth per editor:

| Editor | Trigger auth |
|--------|-------------|
| Claude Code | invoke the `mcp__damsecure__authenticate` tool directly to force the prompt. Fallback: `/mcp` → **damsecure** → Enter → **Authenticate** |
| Cursor | Settings → **MCP** → **damsecure** → **Connect** → complete OAuth |

Complete the browser sign-in when prompted. If the server or auth tool isn't visible yet, the editor hasn't loaded the new config; restart or reload it and retry.

## Step 3: Verify

Call `list_repositories` (in Claude Code: `mcp__damsecure__list_repositories`). If it returns without an auth error, the connection is live. Keep the result; Part A uses it.

---

# Phase 2: Configure

## Part A: Onboard a repository

Use the `list_repositories` result from Step 3 (no arguments; it is org-scoped). Two cases:

- **Repositories already listed.** Report them (name + latest commit) and move on to Part B. Nothing to onboard.
- **Empty list.** The repository still needs to be connected. **Onboarding is not an MCP action**; it happens in the Dam Secure app via the GitHub App. Direct the user to `https://app.damsecure.ai/repositories` and have them connect the repo through the "add / connect repository" flow (this installs or grants the GitHub App on that repo). Onboarding takes roughly 3 to 20 minutes depending on repo size. Wait for them to confirm, then call `list_repositories` again to verify the repo now appears.

Keep the repo `id` from `list_repositories`; it is the `repositoryId` used to filter issues later.

## Part B: Turn on pull request scans

Dam Secure reviews every pull request through a fixed set of built-in vulnerability review lenses (access control, injection, authentication, cryptography, and so on). They are maintained by Dam Secure, so there is nothing to write or tune.

Scans only run once **Pull Request Scans** are turned on. Send the user to the **Rules** page in the app (`https://app.damsecure.ai/vulnerability-rules`): if the lenses show as **Not Running**, an admin turns scans on from that page. There is no MCP tool for this.

## Handoff to Phase 3

Once Part B is done, **always surface Phase 3**. Don't wait to be asked, and don't ask whether they'd like to triage. Configure and Use are one continuous onboarding; the point of setup is the day-to-day loop, so introduce it every time as a capability they now have.

Frame it as **"did you know you can…"**, not **"would you like to…"**. Tell them, in a sentence or two, that from here on they can triage a pull request's findings or work down their outstanding issues right from the editor, then briefly orient them with Part C1 and C2 below. Let them pick where to go next; the framing is informative, not a yes/no gate.

- ✅ "Now that scanning is set up, did you know you can triage a PR's findings right here in the editor? When you open a PR for review, Dam Secure runs as a check on it and you can work through what it flags. You can also work down your outstanding issues the same way."
- ❌ "Would you like to move on to triaging findings now?"

---

# Phase 3: Use (recurring triage)

This is the day-to-day loop. Once Connect and Configure are done, the recurring workflow is:

1. **You open a pull request for review.** Any non-draft PR against the connected repo automatically triggers a scan.
2. **Dam Secure runs as a check on the PR.** Look for the **Dam Secure** entry in the PR's **Checks** / status section on GitHub; its pass/fail state tells you whether the scan surfaced anything.
3. **You triage the findings that check produced.** Bring them into the editor over MCP (scoped by the PR's branch) and decide each one: confirm, dismiss, or mark fixed.

The skill's job here is mostly to **orient the user** to that loop. For each of the two flows below, explain three things (*what it is*, *where to find it*, and *how to configure it*), then hand off to `triage.md` (in this skill's directory) for the actual step-by-step. Both flows are re-entrant; a user can invoke either one on its own once connected.

## Part C1: The PR check and its findings

**What it is.** When a user opens a pull request for review (open, not draft), the Dam Secure GitHub App runs a **check** on that branch and records any findings against it. It shows up alongside your other checks on the PR, named **Dam Secure**. The check itself is a GitHub construct, so what you actually work with in the editor are the *findings it produced*, scoped by the PR's branch name.

**Where to find it.**
- *The check itself* lives on GitHub: open the PR and look at its **Checks** / status section for the **Dam Secure** run and its pass/fail state.
- *The findings* are surfaced in the Dam Secure app, and over MCP via `list_issues branch=<branch>`, which scopes to the latest scan on that branch and exposes a "ready-for-review" count.

**How to configure it.** The check is wired up by connecting the repo's GitHub App in Part A and turning on Pull Request Scans in Part B. There is no MCP toggle for it, and scans run automatically on PR (no manual scan-trigger tool).

**To triage the findings**, follow Flow C1 in `triage.md` (confirm the Dam Secure check on the PR → branch → `list_issues` → `get_issue` → `confirm_finding` / `dismiss_finding` / `fix_finding`).

## Part C2: Outstanding issues

**What it is.** The standing backlog of open issues across all scans, independent of any single PR: the set you work down over time.

**Where to find it.**
- *Bulk* view in the Dam Secure app: `https://app.damsecure.ai/issues`.
- *Focused* over MCP via `list_issues status=open`.

**How to configure / focus it.** Narrow with filters (`severity`, `repositoryId`) and respect pagination (`pageSize` max 100). For a large backlog, use the app's bulk view rather than grinding through hundreds of issues over MCP in one conversation.

**To triage**, follow Flow C2 in `triage.md`.

---

## Common Mistakes

- **Using MCP tools before connecting.** The `damsecure` MCP tools (`list_repositories`, `list_issues`, …) do not exist until Phase 1 finishes and the editor has loaded the server. Connect first.
- **Trying to onboard a repo via MCP.** There is no onboarding tool; repositories are connected in the app via the GitHub App. MCP only detects (`list_repositories`) and, later, triages.
- **Looking for a "CI check" or "scan" tool.** Neither exists. The GitHub check lives on GitHub; scans run automatically on PR. You triage the resulting issues/findings, scoped by branch.
- **Trying to write or tune rules.** The vulnerability review lenses are built in and maintained by Dam Secure. Don't offer to create or edit rules.
- **Reaching for internal tooling.** Do not tell customers to run `ds:triage` or `validate-findings`; those are Dam Secure's own repo skills, not part of this plugin. Use the MCP triage tools and the app's bulk view.
- **Skipping the editor row.** Steps 1 and 2 differ by editor; follow the row for the editor you're actually running in, not the Claude Code one by default.
- **Editing editor config silently.** Always show the MCP config change and confirm before making it.
