---
name: damsecure-triage
description: Use when a user wants to work through and fix Dam Secure security findings — pull findings from the damsecure MCP into a local worklist, bring each finding into context, remediate the code together, mark it fixed, then move to the next. A comprehensive, resumable remediation loop over a pull request's findings or the open-issue backlog. Distinct from damsecure-setup, which only onboards and lightly orients.
---

# Dam Secure Triage (remediation loop)

## Overview

This skill drives a **remediation loop**: it pulls a scoped set of Dam Secure
findings into a local worklist and moves through them one at a time —
understand → decide → **fix the code** → verify → mark fixed → next — until the
list is clear. It is built to grind through a whole PR or backlog in a single
agent session without losing its place.

It is the heavier sibling of `damsecure-setup`. That skill *onboards* you and
*orients* you to triage; this skill *does the triage*, and specifically the part
where you actually change code to close a finding.

**Prerequisite: the `damsecure` MCP must already be connected.** These tools do
not exist until it is. If a `list_issues` tool is not available, stop and run the
Connect phase of `damsecure-setup` first (or invoke the `authenticate` MCP tool
to trigger the browser OAuth), then come back.

> Tool names below are written bare (`list_issues`, `get_issue`, `fix_finding`).
> Invoke them under whatever prefix your editor registered the server with — in
> Claude Code that is `mcp__damsecure__<tool>` when installed via the CLI, or
> `mcp__plugin_damsecure_damsecure__<tool>` when installed via the plugin
> marketplace. Use whichever `*_list_issues` tool is actually present.

## The five steps

The user's mental model — and the order this skill follows:

1. **Query findings** — `list_issues` over a scope you agree on.
2. **Write findings to a local file** — a worklist you can grind through and resume.
3. **Bring each finding into context** — `get_issue` + read the real code.
4. **Work with the user to fix** — propose a diff, apply on approval, verify.
5. **Mark it fixed, get the next** — `fix_finding`, update the worklist, advance.

Steps 3–5 repeat per finding. The detailed per-finding playbook lives in
`remediation-loop.md` (in this skill's directory) — load it before the loop.

## Vocabulary (read once)

- **Issue** — a group of findings from one rule. Has `id`, `severity`, `status`
  (`open` / `acknowledged` / `dismissed`), `ruleId`.
- **Finding** — one scan result at one location, inside an issue. Has a
  `findingId`. **You only get `findingId`s from `get_issue`**, never from
  `list_issues`. Remediation (`fix_finding` / `dismiss_finding`) is per-finding.
- **Branch scoping** — `list_issues` / `get_issue` take a `branch` filter that
  scopes to the *latest scan on that branch* and exposes a "ready-for-review"
  count. This is how PR results are surfaced; there is no PR or CI-check object
  over MCP.

## Quick reference — MCP tools

| Tool | Args | Use |
|------|------|-----|
| `list_issues` | `status?`, `severity?`, `branch?`, `repositoryId?`, `ruleId?`, `title?`, `scanId?`, `sort?`, `page?`, `pageSize?` (max 100) | Query the scope. Paginated. |
| `get_issue` | `id`, `branch?` | Detail + the `findingId`s for one issue. |
| `confirm_finding` | `issueId`, `findingId` | Mark a finding a genuine vulnerability. |
| `fix_finding` | `issueId`, `findingId` | Mark a finding remediated. **Only after the code fix is applied and verified.** |
| `dismiss_finding` | `issueId`, `findingId`, `note?` | Mark a finding a false positive / not relevant. |
| `restore_finding` | `issueId`, `findingId` | Undo a triage (finding → untriaged). |
| `confirm_issue` | `id` | Whole issue → acknowledged (shortcut). |
| `dismiss_issue` | `id`, `dismissalReason`, `dismissalNote?` | Whole issue → dismissed. `dismissalReason` enum: `false_positive` / `wont_fix` / `accepted_risk` / `other`. |
| `update_issue_status` | `id`, `status`, `dismissalReason?`, `dismissalNote?` | `status`: `open` / `acknowledged` / `dismissed`. |

There is **no scan-trigger tool** and **no CI-check object** over MCP. Scans run
automatically on push/PR; you triage what they produced.

---

# Step 0: Preflight and scope

1. **Confirm the MCP is live.** Make one lightweight read call (`list_issues`
   with a small `pageSize`, or `list_repositories`). An auth error means the MCP
   isn't connected — send the user to `damsecure-setup`'s Connect phase, don't
   guess around it.
2. **Agree on the scope** to work through. Ask the user which they want (offer
   these; don't just dump everything):
   - **A pull request** → get the PR's branch name (or confirm the current git
     branch maps to it) and scope with `branch=<branch>`.
   - **The open backlog** → `status=open`, optionally narrowed by
     `severity=critical|high|…`, `repositoryId=…`, or `ruleId=…`.
   - **A single rule or severity** across scans → the matching filter.
3. **Set expectations on size.** If the scope is large (say >~25 issues), say so
   and propose a focus (highest severity first, or one rule at a time). For truly
   large backlogs point at the app's bulk view (`https://app.damsecure.ai/issues`)
   — this loop is for the set actively under remediation, not for clearing
   hundreds in one conversation.

# Step 1: Query findings

Call `list_issues` with the agreed filters. Respect pagination (`pageSize` max
100; page through if needed). Summarize for the user: total issues, breakdown by
severity, and — if branch-scoped — the ready-for-review count.

# Step 2: Write findings to a local worklist file

Enumerate findings and persist them to a **local scratch file** — this is the
queue and the progress ledger, so the loop survives long conversations and can
resume after interruptions. It is session-local and ephemeral by design; it is
not committed to the repo.

- **Location.** Use your session scratchpad directory if you have one; otherwise
  a temp path like `./.damsecure-triage/worklist.md` (tell the user the path).
  Do **not** commit it — finding details can be sensitive.
- **Enumerate findings.** For each issue from Step 1, call `get_issue id=<id>`
  (with `branch=` if branch-scoped) to pull its `findingId`s and locations. To
  keep the main context clean on a large scope, dispatch a subagent to do the
  enumeration and return just the structured rows, then write them yourself.
- **Format.** A markdown checklist, one row per finding. Suggested shape:

  ```markdown
  # Dam Secure triage worklist
  scope: branch=feature/login   |   generated: <when>   |   total findings: 7

  - [ ] #1  issue=ISS-abc  finding=FND-001  sev=high    rule=SQL Injection
        loc=api/users.ts:42   status=pending
        why: user input concatenated into query string
  - [ ] #2  issue=ISS-abc  finding=FND-002  sev=high    rule=SQL Injection
        loc=api/orders.ts:88  status=pending
  - [ ] #3  issue=ISS-def  finding=FND-010  sev=medium  rule=Weak Hash (MD5)
        loc=lib/token.ts:12   status=pending
  ```

  `status` transitions: `pending` → `fixed` / `dismissed` / `confirmed` /
  `skipped`. Update the row (and check the box) the moment a finding is resolved,
  before moving on — the file is the source of truth for "what's left".

# Steps 3–5: The remediation loop (per finding)

Now load **`remediation-loop.md`** and work the worklist top to bottom. For each
`pending` finding, in short:

1. **Bring into context** — pull the finding detail (`get_issue`, cache from
   Step 2) and **read the actual code** at `file:line`. Understand why the rule
   fired.
2. **Decide with the user** — genuine vulnerability, or false positive / accepted
   risk? This needs their judgment; present it clearly, don't auto-decide.
   - False positive / won't fix → `dismiss_finding` (or `dismiss_issue` with a
     `dismissalReason`); mark the row `dismissed`. Next.
   - Genuine → `confirm_finding`, then remediate.
3. **Fix the code** — propose a concrete, minimal diff. Explain it. **Apply it
   only after the user approves.** Match surrounding code style; follow the
   repo's conventions.
4. **Verify** — re-read the changed code; run the build/tests/linter if the repo
   has them; confirm the fix addresses the finding's root cause and didn't break
   anything.
5. **Mark fixed** — call `fix_finding issueId=… findingId=…`. Update the worklist
   row to `fixed` and check the box.
6. **Next** — advance to the next `pending` row. Offer a brief progress line
   every few findings (e.g. "3 fixed, 1 dismissed, 3 to go").

Keep going until no `pending` rows remain, or the user stops. If they stop, the
worklist shows exactly where to resume.

# Step 6: Close out — "is it actually fixed?"

When the list is worked down:

1. **Re-query.** Re-run `list_issues branch=<branch>` (or the same filters) so
   the user sees the ready-for-review / open count drop. Read the delta back to
   them.
2. **Summarize** from the worklist: fixed / dismissed / confirmed-only / skipped,
   with the files touched.
3. **Be honest about what "fixed" means.** `fix_finding` sets the finding's
   **triage status** to remediated — it records *your* verdict; it does **not**
   re-run the scanner. The vulnerability is only independently re-validated by the
   **next scan**, which runs when the fix is pushed / the PR updates. So state it
   as: "code fix applied and locally verified; marked fixed in Dam Secure; the
   next scan on push will confirm it's cleared." Don't claim the scanner
   re-cleared it when it hasn't run yet.
4. If code changed, remind the user to commit/push (a normal git flow, on a
   branch) so the re-scan happens. Committing is the user's call — offer, don't
   assume.

---

## Common mistakes

- **Marking fixed before fixing.** `fix_finding` is the *last* step, after the
  code change is applied **and verified** — not a way to clear the list. If you
  haven't changed code, you haven't fixed it (dismiss it instead, with a reason).
- **Claiming the scanner re-verified.** `fix_finding` is a triage status; the
  re-scan happens on the next push/PR. Say so; don't overstate.
- **Editing without approval.** Propose the diff and get a yes per finding.
  Security fixes can change behavior — the user decides.
- **Batch-dismissing.** Don't dismiss a pile of findings as false positives
  without the user's judgment on each (or an explicit "dismiss all of these").
- **Confusing issues and findings.** `list_issues` gives issues; `findingId`s
  come only from `get_issue`. Remediate per finding.
- **Using MCP tools before connecting.** If `list_issues` isn't present, the MCP
  isn't connected — run `damsecure-setup`'s Connect phase; don't invent tools.
- **Committing the worklist.** It can contain sensitive finding detail. Keep it
  in scratch/ephemeral local storage; never commit it.
- **Grinding a huge backlog over MCP.** Focus by severity/rule; point large
  backlogs at the app's bulk view rather than clearing hundreds in one session.
- **Inventing a scan/CI tool.** There is none. Scans run on push/PR; the GitHub
  check lives on GitHub. You work the findings, scoped by branch.
