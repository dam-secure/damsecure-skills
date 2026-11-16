# Design: `damsecure-setup` onboarding skill

## Problem

Customers asked for a runnable skill that guides them onto Dam Secure. Once a user
has an account they still have to: connect the MCP server to their editor, onboard
a repository so it gets scanned, turn on pull request scans, and then triage the
findings that land on their PRs and in their backlog. Those are exactly the steps a
new customer stumbles on, and after the first one they are all reachable through the
`damsecure` MCP server.

## Solution

A single skill, `damsecure-setup`, distributed as a Claude Code plugin via a git
marketplace. It runs in three phases:

1. **Connect** (Steps 1 to 3, ordered + gated): add the `damsecure` MCP server to
   the editor (confirmed), trigger OAuth via `mcp__damsecure__authenticate`, and
   verify with `list_repositories`.
2. **Configure**: onboard a repository (detect with `list_repositories`; if none,
   hand off to the app's GitHub App flow, then re-verify), then make sure Pull
   Request Scans are turned on from the app's Rules page.
3. **Use** (recurring, re-entrant, detailed in `triage.md`): triage a PR's findings
   scoped by branch (`list_issues branch=<branch>` → `get_issue` → `*_finding`), and
   triage the outstanding open-issue backlog (`list_issues status=open`).

## Key decisions

- **One umbrella plugin for onboarding.** The same skill connects, configures and
  orients the user to triage. Splitting them would duplicate the "is the MCP
  connected?" preflight and make "what do I do after setup?" a separate install.
  The heavier remediation loop lives in its own skill, `damsecure-triage`.
- **Distribution = a multi-plugin git marketplace (`dam-secure/damsecure-skills`, marketplace name `damsecure`).** Each skill is packaged as its own independently-installable plugin under `plugins/<name>/` (`/plugin` menu, or `/plugin install <name>@damsecure`).
- **Fully-guided, not hands-off.** The skill makes the MCP config change itself after one confirmation, runs every read-only MCP call itself, and triggers auth, but never completes browser auth for the user (it can't).
- **Honest about MCP boundaries.** Repository onboarding, turning on scans, and the GitHub check are **not** MCP actions; the skill detects/triages over MCP and hands off to the app (`app.damsecure.ai`) for the parts MCP can't do. There is no scan-trigger tool (scans run on PR). These are called out in "Common Mistakes" so the agent doesn't invent tools.
- **Progressive disclosure.** The connect steps and configure phase live in `SKILL.md`; the two recurring, detail-heavy triage flows (enums, branch semantics, finding-vs-issue) are factored into `triage.md`, loaded on demand.

## Ground-truth reference

| Fact | Value |
|------|-------|
| MCP server | `damsecure` @ `https://api.damsecure.ai/mcp` (HTTP, OAuth), callback port `6843` |
| Install guide | `https://docs.damsecure.ai/mcp/installation` (Claude Code, Cursor, VS Code, Codex) |
| Force-auth tool | `mcp__damsecure__authenticate` (+ `complete_authentication`) |
| Dam Secure app | `https://app.damsecure.ai` (`/repositories`, `/vulnerability-rules`, `/issues`) |

### MCP tools the skills drive

| Domain | Tools |
|--------|-------|
| Repos | `list_repositories` (read-only; **no onboarding tool**, app/GitHub App only) |
| Issues | `list_issues` (`branch`, `status`, `severity`, … filters), `get_issue`, `update_issue_status`, `confirm_issue`, `dismiss_issue` |
| Findings | `confirm_finding`, `dismiss_finding`, `fix_finding`, `restore_finding` |
| Pull requests | `get_pr_review` |

No MCP tool exposes CI check-run status. PR results are reached either by
filtering `list_issues` / `get_issue` on the PR's branch name, or with
`get_pr_review` by owner/repo and PR number.

## Multi-editor support (Claude, Cursor)

`SKILL.md` (the Agent Skills open standard) is read natively by both Claude Code
and Cursor, so one file serves both. No single directory is scanned by both, so
install targets differ:

- `.claude/skills/<name>/`, read by **Claude Code**.
- `.cursor/skills/<name>/`, read by **Cursor** (also `.agents/skills/`; globals `~/.cursor/skills`).

`install.sh` copies each skill's files into the right dir(s) per `--tool`/`--scope`;
the Claude plugin marketplace remains the premium Claude path. The `SKILL.md` is
editor-aware only in the two steps that differ (adding the MCP server, MCP auth),
via a per-editor table the running agent matches to its own environment.

## Out of scope (for now)

- **Copilot** and **Codex** both read the Agent Skills `SKILL.md`
  (Copilot from repo `.claude/skills`; Codex from `.agents/skills`), so they can
  be added later with minimal change, but are not targeted now.
- A repository-onboarding MCP tool (would remove the app hand-off in Configure).
- Bulk finding triage over MCP (the app's bulk view owns large backlogs; the skill
  points there).
- Publishing to a shared/central marketplace registry.
