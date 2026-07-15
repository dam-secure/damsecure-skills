# Design: `damsecure-setup` onboarding skill

> Renamed from `secure-spec-setup` in v0.2.0 and broadened from "connect Secure Spec"
> to full-lifecycle onboarding. History below notes what was net-new at each step.

## Problem

Customers asked for a runnable skill that guides them onto Dam Secure. The first
version (`secure-spec-setup`) covered only the **connect** phase: it installed the
`damsecure` CLI (which installs the editor plugin: hooks + MCP config) and did the
two OAuth flows, but stopped once Secure Spec plan review was live.

That left the rest of the product undocumented as a guided flow. Once connected, a
user still has to: onboard a repository so it gets scanned, understand the rules we
create for them and add their own, and then triage the findings that land on their
PRs and in their backlog. Those are exactly the steps a new customer stumbles on,
and they are all reachable through the same `damsecure` MCP server the connect phase
already sets up.

The plans-directory **discovery** step remains genuinely net-new: the CLI has
configuration (`damsecure plan-dirs set`) and built-in path heuristics, but **no
logic that scans a repo to suggest where plans live**.

## Solution

A single skill, `damsecure-setup`, distributed as a Claude Code plugin via a git
marketplace. It runs in three phases:

1. **Connect** (Steps 1 to 5, ordered + gated, unchanged from the original skill):
   read-only plans discovery (subagent, brief in `discover-plans.md`); CLI install
   (`curl … install.sh | bash`, confirmed) which runs `damsecure setup` + reload;
   confirm/persist plans dir (`damsecure plan-dirs set`); trigger MCP auth via
   `mcp__damsecure__authenticate`; verify via `list_rules`. Payoff: Secure Spec
   `review_plan` fires automatically on plan save.
2. **Configure**: onboard a repository (detect with `list_repositories`; if none,
   hand off to the app's GitHub-App flow, then re-verify), then review rules
   (`list_rules type=vulnerability` / `type=team`), add custom `team` rules
   (`create_rule`), and scope them per project (`enable_rule_for_project`).
3. **Use** (recurring, re-entrant, detailed in `triage.md`): triage a PR's findings
   scoped by branch (`list_issues branch=<branch>` → `get_issue` → `*_finding`), and
   triage the outstanding open-issue backlog (`list_issues status=open`).

## Key decisions

- **One umbrella plugin, not two.** `damsecure setup` connects the CLI + MCP once;
  the same skill then configures and uses the product. Splitting connect from
  configure/triage would duplicate the "is the MCP connected?" preflight and make
  the "what do I do after setup?" question a separate install. The rename to
  `damsecure-setup` reflects that it is the product's front door, not just the
  Secure Spec sub-feature.
- **Distribution = a multi-plugin git marketplace (`dam-secure/damsecure-skills`, marketplace name `damsecure`).** Most widely used first-party mechanism; the CLI itself uses `claude plugin marketplace add` internally. Each skill is packaged as its own independently-installable plugin under `plugins/<name>/` (`/plugin` menu, or `/plugin install <name>@damsecure`). Must be independent of the CLI because of the chicken-and-egg: the onboarding skill guides the CLI install, so it can't be delivered by the CLI's own plugin.
- **Fully-guided, not hands-off.** The skill runs discovery, `plan-dirs set`, and every read-only MCP call itself, confirms once before `curl|bash`, and triggers auth, but never completes browser auth for the user (it can't).
- **Honest about MCP boundaries.** Repository onboarding and the GitHub CI check are **not** MCP actions; the skill detects/triages over MCP and hands off to the app (`app.damsecure.ai`) for the parts MCP can't do. `create_rule` is `team`-only. There is no scan-trigger tool (scans run on push/PR). These are called out in "Common Mistakes" so the agent doesn't invent tools.
- **Progressive disclosure.** The connect steps and configure phase live in `SKILL.md`; the two recurring, detail-heavy triage flows (enums, branch semantics, finding-vs-issue) are factored into `triage.md`, loaded on demand.
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
| Dam Secure app | `https://app.damsecure.ai` (`/repositories`, `/rules`, `/vulnerability-rules`, `/issues`) |

### MCP tools the skill drives (source: `packages/api/src/mcp/tools/` in the monorepo)

| Domain | Tools |
|--------|-------|
| Repos | `list_repositories` (read-only; **no onboarding tool** — app/GitHub-App only) |
| Rules | `list_rules`, `get_rule`, `create_rule` (`team` only), `update_rule` |
| Rule scoping | `get_all_projects_by_repo`, `get_projects_for_rule`, `enable_rule_for_project`, `disable_rule_for_project`, `list_rule_projects` |
| Issues | `list_issues` (`branch`, `status`, `severity`, … filters), `get_issue`, `update_issue_status`, `confirm_issue`, `dismiss_issue` |
| Findings | `confirm_finding`, `dismiss_finding`, `fix_finding`, `restore_finding` |
| Plans | `review_plan` |

No MCP tool exposes GitHub PR objects or CI check-run status; PR results are reached
by filtering `list_issues` / `get_issue` on the PR's branch name.

## Multi-editor support (Claude, Cursor)

`SKILL.md` (the Agent Skills open standard) is read natively by both Claude Code
and Cursor, so one file serves both. No single directory is scanned by both, so
install targets differ:

- `.claude/skills/<name>/`, read by **Claude Code**.
- `.cursor/skills/<name>/`, read by **Cursor** (also `.agents/skills/`; globals `~/.cursor/skills`).

`install.sh` copies the skill (`SKILL.md`, `discover-plans.md`, `triage.md`) into the
right dir(s) per `--tool`/`--scope`; the Claude plugin marketplace remains the premium
Claude path. The `SKILL.md` is editor-aware only in the two steps that differ
(post-install reload, MCP auth), via a per-editor table the running agent matches to
its own environment.

## Out of scope (for now)

- **Copilot** and **Codex** both read the Agent Skills `SKILL.md`
  (Copilot from repo `.claude/skills`; Codex from `.agents/skills`), so they can
  be added later with minimal change, but are not targeted now.
- A repository-onboarding MCP tool (would remove the app hand-off in Configure).
- Bulk finding triage over MCP (the app's bulk view owns large backlogs; the skill
  points there).
- Publishing to a shared/central marketplace registry.
