---
name: damsecure-pr-review
description: Use when an automated review agent needs Dam Secure's security scan results for a specific pull request — ask "do you have scan results for this PR, and what are they?" via the get_pr_review MCP tool, poll until the scan finishes, and fold the findings into your own risk determination. Built for agents running unattended in a CI/CD pipeline (Buildkite, GitHub Actions). Distinct from damsecure-triage, which is a human-in-the-loop loop that fixes findings.
---

# Dam Secure PR review over MCP

## Overview

You are an automated review agent. A pull request is in front of you, you are
forming your own verdict on it, and Dam Secure has (probably) already scanned it.
This skill is how you ask for that scan and read the answer correctly.

One tool does it: **`get_pr_review`** — give it a repository and a PR number, and
it returns either the findings for that pull request or a machine-readable
statement of why they are not available and whether waiting will help.

**Dam Secure does not appear as a separate check on the PR in this mode.** You
are the reviewer; Dam Secure is one input to your determination.

<EXTREMELY-IMPORTANT>
An empty `issues[]` is an answer **only** when `status` is `complete`.

Scans take minutes and you may call at any point in that window. On every other
status an empty `issues[]` means *not known yet*, not *clean*. Reporting "no
security issues found" off a `running` response is the worst failure mode
available to you: it is indistinguishable from a real all-clear, and it is wrong.

If you cannot reach a `complete` (or terminal `not_scanned`) answer within your
budget, say **"Dam Secure results unavailable"**. Never say "clean".
</EXTREMELY-IMPORTANT>

This skill is autonomous by design — there is no user to ask. Every branch below
resolves to an action you take yourself.

> Tool names are written bare (`get_pr_review`). Invoke them under whatever
> prefix your MCP client registered the Dam Secure server with — commonly
> `mcp__damsecure__get_pr_review`.

---

# Step 0: Preflight

**The Dam Secure MCP connection is already configured** — whoever installed you
set it up. Authentication is not your job and this skill does not cover it.

One check before you start: **is a `get_pr_review` tool actually present?** If
it is not, the MCP server is not connected or is registered under a name you
have not looked for. Stop and report that, naming the tool you expected. Do not
substitute another tool and do not proceed.

If a call fails with an authentication or connection error, that is an
**infrastructure failure, not a security result**. Report the pull request as
unreviewed by Dam Secure and let your pipeline's own policy decide whether that
blocks. Never degrade it into "no issues found".

# Step 1: Build the call

| Param | Type | Notes |
|---|---|---|
| `repository` | string | `owner/repo`, e.g. `dam-secure/monorepo`. Required. |
| `prNumber` | integer | Required. |
| `headSha` | string | The commit CI is building. Optional, **always send it**. |

All three values are in your pipeline environment already. Read them; don't ask
for them. Two places where the obvious variable is the wrong one:

- **`repository` is a slug, not a URL.** GitHub Actions gives you
  `GITHUB_REPOSITORY` in exactly the right form. Buildkite's `BUILDKITE_REPO` is a
  clone URL (`git@github.com:owner/repo.git`) — strip it down to `owner/repo`.
- **`headSha` must be the PR's head commit.** On a GitHub Actions
  `pull_request` event, `GITHUB_SHA` is the *merge* commit, which Dam Secure never
  scanned and never recorded — send `github.event.pull_request.head.sha` instead.
  Buildkite's `BUILDKITE_COMMIT` is already the head commit.

**Always send `headSha`.** It is the only way the tool can tell current results
from stale ones. Without it you get `scan.isCurrent: null` — the tool will not
guess, and neither should you. Sending the *wrong* SHA is worse than sending
none: a commit Dam Secure has no row for reads as "not scanned yet" and you will
poll for a scan that already finished.

`repository` is resolved **inside your organisation only**. A repository
belonging to another tenant returns `repository_not_found`, identical to one that
does not exist — deliberate, not a bug to route around.

# Step 2: The poll loop

`get_pr_review` returns immediately and never waits server-side. **You own the
retry loop.** One field drives it:

> **`retryAfterSeconds`** — sleep that many seconds, then call again with
> **identical arguments**. When it is `null`, the answer is final: **stop**.

```
deadline = now + your_budget          # 10 minutes is a sane default
loop:
  r = get_pr_review(repository, prNumber, headSha)
  if r.retryAfterSeconds == null:  break        # terminal — act on r
  if now + r.retryAfterSeconds > deadline: break  # give up, report unavailable
  sleep(r.retryAfterSeconds)
```

Three rules that keep this loop honest:

1. **`null` means stop.** It is `null` on every terminal outcome, *including*
   `failed` and the `scan_trigger_on_pr_open` case where results exist for an
   older commit and no rescan is ever coming. Polling past `null` loops forever.
2. **Never invent a retry.** Do not reason "the latest scan is for an older SHA,
   so a newer one must be coming" — on organisations configured to scan only at
   PR open, it is not. The tool has already read that setting for you; trust
   `retryAfterSeconds` over your own inference.
3. **Bound it yourself.** PR scans run in minutes. Set a wall-clock deadline and
   an outcome for hitting it: report **unavailable**, not clean. `scan.startedAt`
   and `pendingScan.startedAt` let you compute elapsed time if you want your own
   backoff instead of the suggested 30s.

There is **no tool to trigger a scan.** Scans fire automatically on the
`pull_request` webhook. If no scan is coming, the response says so — that is an
answer, not something to fix by calling harder.

# Step 3: Status → action

Six statuses. Branch on `status` first; read `reason` only for `not_scanned`.

| `status` | What it means | `retryAfterSeconds` | Do this |
|---|---|:---:|---|
| `complete` | Final answer for the requested commit | `null` | Use `issues[]`. This is the only status where `[]` means clean. |
| `pending` | Scan queued or expected for this commit | 30 | Sleep and re-call. Meanwhile `issues[]` may hold the *previous* commit's findings. |
| `running` | Scan in progress for this commit | 30 | Same as `pending`. |
| `failed` | Scan errored | `null` | **Surface, don't block.** Report "Dam Secure scan failed" and fall back to your own analysis. Carries a previous commit's results if one completed. |
| `not_scanned` | No scan record — read `reason` | `null`, except `awaiting_webhook` | See the table below. |
| `repository_not_found` | Repo not onboarded to this organisation | `null` | Terminal. Report that the repo isn't covered by Dam Secure. Do not retry, do not treat as clean. |

## `not_scanned` reasons

| `reason` | Meaning | Do this |
|---|---|---|
| `scans_disabled` | PR scans are off for this repo or org | Terminal. Say scanning is disabled — this is a config choice, not a failure. |
| `draft_pull_request` | Dam Secure does not scan drafts | Terminal and **entirely normal**. Not an error; do not report it as one. |
| `base_branch_not_default` | PR does not target the default branch | Terminal. Dam Secure only scans PRs into the default branch. The message names both branches. |
| `pull_request_not_found` | The provider has no such PR | Terminal. Check `prNumber` and `repository` — most likely your own argument is wrong. |
| `awaiting_webhook` | PR is open, non-draft, targets the default branch, and there is **still** no record | **The only retryable reason** (`retryAfterSeconds: 30`), and the only one that indicates a fault on Dam Secure's side. Poll to your deadline; if it never resolves, report unavailable and flag it — webhook delivery or ingestion may be broken. |

# Step 4: Read the results

Two independent slots. Neither is ever overloaded:

- **`scan`** — describes the scan that produced `issues[]`. `null` when no scan
  has *ever* completed for this PR.
- **`pendingScan`** — describes work still expected for the requested commit.
  `null` when nothing is coming.

**The one rule: `issues[]` is populated exactly when `scan` is non-null,
whatever the `status`.** So a `running` or `failed` response still carries the
previous commit's findings when one exists. You are never left with nothing you
could have had. `issues[]` is `[]` only when no scan has ever completed.

Both slots being set is the *common* case on a busy PR: a fresh push means
`pendingScan` describes the in-flight scan while `scan` + `issues[]` hold the
previous commit's completed results with **`isCurrent: false`**. Act on the older
findings now or wait for fresh ones — your call, made on explicit data.

`scan.isCurrent`:

| Value | Meaning |
|---|---|
| `true` | Results are for the commit you asked about. |
| `false` | Results are for an **earlier** commit. Still real findings — say which commit. |
| `null` | Unknowable, because you omitted `headSha`. Go back to Step 1 and send it. |

`scan.notRescannedReason: "scan_trigger_on_pr_open"` alongside
`isCurrent: false` and `status: complete` is **a complete answer, not a stale
one**: this organisation scans only when a PR opens, so the open-time scan
stands and later commits are never rescanned. Report the findings, name the
commit they came from, and stop. Do not poll.

`summary` keeps you honest about volume: `totalIssues` is the real total,
`returnedIssues` is what you got, and `issues[]` is capped at **50** sorted
severity-descending. When `truncated` is `true` you are looking at the top 50 of
a larger set — say so rather than implying you saw everything.

The full response schema, every enum value, and the nested issue/finding shape
are in **`response-reference.md`** (this skill's directory). Load it when you
need field-level detail.

# Step 5: Fold it into your own risk determination

Dam Secure returns structured data, not a verdict. You decide. Each issue gives
you the reasoning to decide *with*:

- `severity` (`critical` / `high` / `medium` / `low` / `info`) and
  `severityRationale` — *why* it is rated that way.
- `attackScenario` — the concrete exploit path. The most useful field for
  judging real-world risk.
- `confidence`, `cwe`, `source` (`vulnerability` or `team` — a customer-authored
  rule), and `recommendation`.
- `findings[]` — per-location detail: `filePath`, `startLine`, `relevantCode`,
  `explanation`, plus `evidenceEntries` / `supportingRefs`.

When you report, always state **three** things together: the findings, the
commit they were scanned at (`scan.scannedHeadSha`), and whether that is the
commit under test (`isCurrent`). A finding list without a commit is unverifiable.

**Composing with triage.** `issueId` and `findingId` are the same UUIDs the
triage tools accept — `dismiss_finding`, `confirm_finding`, `fix_finding`,
`confirm_issue`, `dismiss_issue` — so you can act on a finding without a second
lookup. But those tools **mutate state and require the `mcp:write` scope**, which
read-only credentials do not carry. Even where the scope is present, do not
silently dismiss findings from an unattended pipeline: that erases a human's
security decision. Read here; let a person triage. The guided remediation loop is
the **`damsecure-triage`** skill, not this one.

---

## Common mistakes

- **Reading empty as clean.** `issues: []` is only an all-clear under
  `status: complete`. Anywhere else it means unknown. This is the whole reason
  the status field exists.
- **Polling past `null`.** `retryAfterSeconds: null` is terminal on *every*
  status, including `failed` and `scan_trigger_on_pr_open`.
- **Inferring a rescan from a SHA mismatch.** Organisations set to scan only at
  PR open never rescan later commits. Reasoning "older SHA, therefore a newer
  scan is coming" polls forever on those tenants. Read `retryAfterSeconds`.
- **Omitting `headSha`, or sending a merge commit.** Omitting it loses all
  current-vs-stale detection (`isCurrent: null`). Sending a synthetic merge SHA
  (GitHub Actions' `GITHUB_SHA` on a `pull_request` event) is worse: Dam Secure
  has no row for it, so a finished scan reads as "not scanned yet". Send the PR's
  head commit.
- **Passing an internal id as `repository`.** It takes the `owner/repo` slug from
  your CI environment, not a UUID. `pullRequest.repositoryId` comes back in the
  response but is Dam Secure's internal identifier — you never need to send it.
- **Trying to trigger a scan.** No such tool. The `pull_request` webhook owns
  that. If nothing is coming, the response tells you why.
- **Treating `draft_pull_request` or `scans_disabled` as failures.** Both are
  normal, deliberate, terminal answers. Only `awaiting_webhook` indicates
  something wrong on Dam Secure's side.
- **Blocking a PR on `failed`.** A scan error is not a vulnerability. Surface it
  and fall back to your own analysis.
- **Turning an auth or network error into a security result.** An unreachable
  MCP means *unreviewed*, never *clean*.
- **Hiding truncation.** With `summary.truncated: true` you saw the top 50 of
  `totalIssues`. Report the real total.
- **Writing state from an unattended pipeline.** Triage tools need `mcp:write`
  and represent a human judgment. Read here; let a person triage.
