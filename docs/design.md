# Design: `secure-spec-setup` onboarding skill

## Problem

Customers asked for a runnable skill that guides them through Dam Secure **Secure Spec** setup. Today the `damsecure setup` command installs a Claude Code *plugin* (hooks + MCP config) and does CLI OAuth, but nothing:

- explains the flow up front,
- discovers where a repo's plans already live, or
- ties install → plans-directory config → MCP auth into one guided pass.

The plans-directory **discovery** step is genuinely net-new: the CLI has configuration (`damsecure plan-dirs set`) and built-in path heuristics, but **no logic that scans a repo to suggest where plans live**.

## Solution

A single skill, `secure-spec-setup`, distributed as a Claude Code plugin via a git marketplace. Five ordered, gated steps:

1. Preview + read-only plans discovery (subagent, brief in `discover-plans.md`).
2. CLI install: `curl … install.sh | bash` (confirmed) → runs `damsecure setup` → `/reload-plugins`.
3. Confirm + persist plans dir: `damsecure plan-dirs set <dir>`.
4. Trigger MCP auth directly via the `mcp__damsecure__authenticate` tool (manual `/mcp` fallback).
5. Verify via `mcp__damsecure__list_rules`; explain the automatic `review_plan`.

## Key decisions

- **Distribution = a multi-plugin git marketplace (`dam-secure/damsecure-skills`, marketplace name `damsecure`).** Most widely used first-party mechanism; the CLI itself uses `claude plugin marketplace add` internally. Each skill is packaged as its own independently-installable plugin under `plugins/<name>/`, so users pick exactly what they want (`/plugin` menu, or `/plugin install <name>@damsecure`). `secure-spec-setup` is the first plugin. Must be independent of the CLI because of the chicken-and-egg: the onboarding skill guides the CLI install, so it can't be delivered by the CLI's own plugin.
- **Fully-guided, not hands-off.** The skill runs discovery and `plan-dirs set` itself, confirms once before `curl|bash`, and triggers the auth tool — but never completes browser auth for the user (it can't).
- **Two OAuth flows are surfaced explicitly** (CLI in Step 2, MCP in Step 4) so the second prompt isn't a surprise.

## Ground-truth reference

| Fact | Value |
|------|-------|
| Install | `curl -fsSL https://app.damsecure.ai/resources/cli/install.sh \| bash` |
| Setup | `damsecure setup` (auto-detects Claude/Cursor/VS Code/Copilot) |
| MCP server | `damsecure` @ `https://api.damsecure.ai/mcp` (HTTP, OAuth+PKCE via Kinde), callback port `6843` |
| Force-auth tool | `mcp__damsecure__authenticate` (+ `complete_authentication`) |
| Plan-review tool | `review_plan` (args `planId`, optional `readiness`) |
| Plans config | `~/.damsecure/config.json` → `planDirs`; env `DAMSECURE_PLAN_DIRS`; default = heuristics |
| Built-in plan paths | `specs/`, `plans/`, `rfcs/`, `proposals/`, `docs/plans/`, `.claude/plans/`, `*.plan.md` |
| CLI Claude install | `claude plugin marketplace add ~/.damsecure/plugin/claude` + `claude plugin install damsecure@damsecure-local` |

## Multi-editor support (Claude, Cursor)

`SKILL.md` (the Agent Skills open standard) is read natively by both Claude Code
and Cursor — so one file serves both. No single directory is scanned by both, so
install targets differ:

- `.claude/skills/<name>/` — read by **Claude Code**.
- `.cursor/skills/<name>/` — read by **Cursor** (also `.agents/skills/`; globals `~/.cursor/skills`).

`install.sh` copies the skill into the right dir(s) per `--tool`/`--scope`; the
Claude plugin marketplace remains the premium Claude path. The `SKILL.md` is
editor-aware only in the two steps that differ (post-install reload, MCP auth),
via a per-editor table the running agent matches to its own environment.

## Out of scope (for now)

- **Copilot** and **Codex** — both also read the Agent Skills `SKILL.md`
  (Copilot from repo `.claude/skills`; Codex from `.agents/skills`), so they can
  be added back later with minimal change, but are not targeted now.
- Publishing to a shared/central marketplace registry.
- Folding the skill back into the CLI plugin once a customer is set up.
