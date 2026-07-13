---
name: secure-spec-setup
description: Use when a user wants to install, set up, onboard, or connect Dam Secure Secure Spec in their repo — installing the damsecure CLI, choosing where plans live, or authenticating the Secure Spec MCP server.
---

# Secure Spec Setup

## Overview

Guides a user end-to-end through Dam Secure **Secure Spec** onboarding. Secure Spec reviews your implementation **plans** for security issues before you write code, via an editor plugin/extension (hooks + an MCP server) that the `damsecure` CLI installs.

This skill works in **Claude Code, Cursor, and GitHub Copilot**. The flow is identical; only two steps differ per editor (post-install reload in Step 2, MCP auth in Step 4). Detect which editor you're running in and follow the matching row in those steps.

Run the five steps **in order**. Each step gates the next: the CLI must be installed before plans can be configured, and the plugin must be loaded before the MCP server can authenticate. Do not skip ahead or batch steps.

Official reference: https://docs.damsecure.ai/secure-spec/installation

## Quick Reference

| Thing | Value |
|-------|-------|
| Install command | `curl -fsSL https://app.damsecure.ai/resources/cli/install.sh \| bash` |
| Setup (run by installer) | `damsecure setup` (auto-detects Claude / Cursor / VS Code+Copilot) |
| Set plans directory | `damsecure plan-dirs set <dir>` |
| Plans config file | `~/.damsecure/config.json` (`planDirs` key) |
| MCP server | `damsecure` → `https://api.damsecure.ai/mcp` (HTTP, OAuth) |
| Plan-review tool | `review_plan` (fires automatically when you save a plan) |

## Step 1 — Preview and find where plans already live (read-only)

First tell the user what the next four steps will do (install CLI, set plans directory, connect MCP), and that they'll authenticate **twice** in a browser: once for the CLI, once for the MCP server. Nothing is installed yet.

Then find where plans already live in the repo, following the brief in `discover-plans.md` (in this skill's directory). If your editor supports subagents (e.g. Claude Code), dispatch one so the file listing doesn't flood the main context; otherwise do it inline but keep only the ranked summary, not the raw listing. Report the ranked candidate directories to the user. Do not set anything yet — Step 3 persists the choice after the CLI exists.

## Step 2 — Install the CLI

The installer runs `curl … | bash`, which downloads the `damsecure` binary and runs `damsecure setup` — this opens a browser for CLI OAuth and installs the Secure Spec plugin/extension (hooks + MCP config) into every editor it detects.

Because this is `curl | bash` and modifies the user's editor config, **show the exact command and get explicit confirmation before running it**:

```bash
curl -fsSL https://app.damsecure.ai/resources/cli/install.sh | bash
```

If the user prefers, they can run it themselves in a terminal instead. Then reload so the new plugin/MCP registers, per your editor:

| Editor | Reload step |
|--------|-------------|
| Claude Code | run `/reload-plugins` (or restart Claude Code) |
| Cursor | open MCP settings and enable/refresh the `damsecure` server (or reload the window) |
| VS Code + Copilot | reload the window (Command Palette → *Developer: Reload Window*) |

## Step 3 — Confirm and set the plans directory

Present the candidate(s) from Step 1 and ask the user to confirm one (or supply their own repo-relative path, e.g. `docs/plans`, `specs`, `docs/superpowers/plans`). Then persist it:

```bash
damsecure plan-dirs set <confirmed-dir>
```

Verify with `damsecure plan-dirs list`. This writes `planDirs` to `~/.damsecure/config.json`; from then on, only plans saved under a configured directory are reviewed.

If Step 1 found no plausible plans directory, tell the user Secure Spec falls back to built-in detection (`specs/`, `plans/`, `rfcs/`, `proposals/`, `docs/plans/`, `.claude/plans/`, and `*.plan.md` files) and let them either accept that or set an explicit directory.

## Step 4 — Connect the MCP server (trigger auth)

The `damsecure` MCP server is registered but not yet authenticated. This is a **separate** OAuth from the CLI login in Step 2 (MCP auth is per-editor). Trigger it per your editor:

| Editor | Trigger auth |
|--------|-------------|
| Claude Code | invoke the `mcp__damsecure__authenticate` tool directly to force the prompt. Fallback: `/mcp` → **damsecure** → Enter → **Authenticate** |
| Cursor | Settings → **MCP** → **damsecure** → **Connect** / **Login** → complete OAuth |
| VS Code + Copilot | open the MCP view (or `mcp.json`) → **Start** the `damsecure` server → complete OAuth |

Complete the browser sign-in when prompted. If the server or auth tool isn't visible yet, the user hasn't reloaded since Step 2 — do the reload for their editor and retry.

## Step 5 — Verify

Confirm the connection works by invoking a lightweight read-only MCP tool, e.g. `list_rules` (in Claude Code: `mcp__damsecure__list_rules`). If it returns without an auth error, setup is complete.

Tell the user what happens next: when they save an implementation plan under the configured directory, Secure Spec's `review_plan` runs automatically and surfaces any security concerns before they build. Point them at https://docs.damsecure.ai/secure-spec/installation for details.

## Common Mistakes

- **Setting plan-dirs before installing the CLI** — `damsecure plan-dirs set` doesn't exist until Step 2 completes. Keep the order.
- **Expecting one login** — there are two OAuth flows: CLI (Step 2) and MCP (Step 4). Tell the user up front so the second prompt isn't a surprise.
- **MCP server/tool "missing"** — it only appears after the plugin loads. Do the editor-specific reload in Step 2 before Step 4.
- **Skipping the editor row** — Steps 2 and 4 differ by editor; follow the row for the editor you're actually running in, not the Claude Code one by default.
- **Auto-running `curl | bash`** — always show the command and confirm first; never pipe-to-bash silently.
