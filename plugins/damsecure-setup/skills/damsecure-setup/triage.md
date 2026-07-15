# Triage reference (PR findings and outstanding issues)

Detailed flow for Phase 3 of `SKILL.md`. Triage is **interactive**: the confirm / dismiss / fix decision needs the user's judgment, so present each item clearly and let them decide. Do not batch-dismiss without asking.

## Vocabulary

- **Issue**: a group of one or more findings detected by a single rule. Has an `id`, `severity`, `status` (`open` / `acknowledged` / `dismissed`), and a `ruleId`.
- **Finding**: an individual scan result inside an issue, at a specific location. Has a `findingId`. You only get `findingId`s from `get_issue`.
- **Branch scoping**: `list_issues` / `get_issue` accept a `branch` filter that scopes to the **latest scan on that branch** and exposes a "ready-for-review" count. This is how PR-level results are surfaced; there is no PR or CI-check object over MCP.

## Choosing finding-level vs issue-level

- Triage **at the finding level** (`confirm_finding` / `dismiss_finding` / `fix_finding`) when an issue has multiple findings and they deserve different verdicts (one real, one false positive).
- Triage **at the issue level** (`confirm_issue` / `dismiss_issue`) when the whole issue is uniformly right or wrong, as a shortcut.
- `restore_finding` moves a triaged finding back to untriaged if the user changes their mind.

## Tool arguments

| Tool | Args | Notes |
|------|------|-------|
| `list_issues` | `status?`, `severity?`, `branch?`, `repositoryId?`, `ruleId?`, `title?`, `scanId?`, `sort?`, `page?`, `pageSize?` | Paginated; `pageSize` max 100. |
| `get_issue` | `id`, `branch?` | Returns findings, each with a `findingId`. |
| `confirm_finding` | `issueId`, `findingId` | Marks a finding a genuine vulnerability. |
| `dismiss_finding` | `issueId`, `findingId`, `note?` | Marks a finding a false positive / not relevant. |
| `fix_finding` | `issueId`, `findingId` | Marks a finding fixed / remediated. |
| `restore_finding` | `issueId`, `findingId` | Undo a triage. |
| `confirm_issue` | `id` | Whole issue → acknowledged. |
| `dismiss_issue` | `id`, `dismissalReason`, `dismissalNote?` | Whole issue → dismissed. |
| `update_issue_status` | `id`, `status`, `dismissalReason?`, `dismissalNote?` | `status`: `open` / `acknowledged` / `dismissed`. |

**`dismissalReason` is an enum** (required when dismissing an issue): `false_positive`, `wont_fix`, `accepted_risk`, `other`. Ask the user which applies rather than guessing; add a `dismissalNote` for context.

## Flow C1: Triage a pull request

1. Establish the branch. Ask for the PR's branch name, or use the current git branch if the user confirms it maps to the PR.
2. `list_issues branch=<branch>` (optionally `status=open` to hide already-triaged). Summarize: how many issues, by severity, and the ready-for-review count.
3. For each issue the user wants to look at, `get_issue id=<id> branch=<branch>` and present the findings (file, line, why it fired).
4. Take the user's verdict per finding (or per issue) and call the matching tool.
5. When done, re-run `list_issues branch=<branch>` so the user sees the ready-for-review count drop to zero (or what remains).

## Flow C2: Triage outstanding issues

1. `list_issues status=open` with any focusing filters the user wants (`severity=critical`, a specific `repositoryId`, or `ruleId`). Respect pagination; work a page at a time.
2. `get_issue` for detail on each.
3. Triage as in C1 (finding-level or issue-level), filling `dismissalReason` from the enum when dismissing.
4. For a large backlog, stop after a focused batch and point the user at the app's bulk triage view (`https://app.damsecure.ai/issues`); MCP triage is best for the set actively under review, not for clearing hundreds of issues in one conversation.
