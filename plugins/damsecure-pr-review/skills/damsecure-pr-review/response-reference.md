# `get_pr_review` response reference

Field-level detail for the tool driven by `SKILL.md`. Load this when you have a
payload in hand and need to know exactly what a field means. The poll loop, the
status→action mapping, and the "empty is not clean" rule live in `SKILL.md`.

The tool returns a **single JSON text block**. `issues[]` is structured data —
you decide how to render it.

---

## Top level

| Field | Type | Notes |
|---|---|---|
| `status` | enum | `complete` / `pending` / `running` / `failed` / `not_scanned` / `repository_not_found` |
| `reason` | enum \| null | Set only when `status` is `not_scanned`. See [Reasons](#reasons). |
| `message` | string | Human-readable summary. Safe to log or quote; contains no internal ids, paths, or SQL. |
| `retryAfterSeconds` | number \| null | `30` when re-calling can change the answer; `null` when the answer is final. **The only field the poll loop needs.** |
| `pullRequest` | object | See below. Always present unless `repository_not_found`. |
| `scan` | object \| null | The scan that produced `issues[]`. `null` = no scan has ever completed for this PR. |
| `pendingScan` | object \| null | Work still expected for the requested commit. `null` = nothing is coming. |
| `summary` | object | Counts and truncation state. |
| `issues` | array | Populated **exactly when `scan` is non-null**, whatever the `status`. |

### `pullRequest`

| Field | Type | Notes |
|---|---|---|
| `number` | integer | The PR number you asked for. |
| `repository` | string | Resolved `owner/repo`. |
| `repositoryId` | string | Dam Secure's internal UUID for the repository. Informational — you address repositories by `owner/repo`, never by this. |
| `headRef` | string | Source branch. Also the `branch` filter accepted by `list_issues` / `get_issue`. |
| `baseRef` | string | Target branch. Dam Secure only scans PRs targeting the default branch. |
| `headSha` | string | Head commit of the PR as Dam Secure last recorded it. Not necessarily the SHA you asked about. |
| `state` | string | `open` / `closed`. |

### `scan`

Describes **the scan whose findings are in `issues[]`** — which is not always a
scan of the commit you asked about.

| Field | Type | Notes |
|---|---|---|
| `scanId` | string | UUID of the scan. |
| `scannedHeadSha` | string | The commit these findings were produced from. **Always report this alongside the findings.** |
| `isCurrent` | boolean \| null | `true` = matches your `headSha`. `false` = earlier commit. `null` = you omitted `headSha`, so staleness is unknowable. |
| `notRescannedReason` | enum \| null | `scan_trigger_on_pr_open` when results are deliberately not being refreshed. Otherwise `null`. |
| `startedAt` | ISO 8601 string | Use for your own elapsed-time backoff. |
| `completedAt` | ISO 8601 string | |

### `pendingScan`

| Field | Type | Notes |
|---|---|---|
| `scanId` | string \| null | `null` when `status` is `expected`. |
| `status` | enum | `pending` (queued) / `running` (in progress) / `expected` (due for this commit, record not seen yet) |
| `startedAt` | ISO 8601 string \| null | `null` when `status` is `expected`. |

`pendingScan.status: "expected"` pairs with a top-level `status: pending` and
means Dam Secure knows a scan is due for this commit but the webhook has not
landed. Retryable.

### `summary`

| Field | Type | Notes |
|---|---|---|
| `totalIssues` | integer | The **real** total for the scan, before capping. |
| `bySeverity` | object | `{ critical, high, medium, low, info }` — counts over the real total. |
| `returnedIssues` | integer | How many are in `issues[]`. |
| `truncated` | boolean | `true` when `totalIssues` exceeded the 50-issue cap. Report the real total when true. |

`issues[]` is sorted **severity-descending** and capped at **50**, so a truncated
response gives you the 50 most severe — never a random subset.

---

## Reasons

### `reason` — why there is no scan record (`status: not_scanned`)

| Value | Terminal? | Meaning |
|---|:---:|---|
| `scans_disabled` | yes | PR scanning is off for this repository or organisation. |
| `draft_pull_request` | yes | Draft PRs are not scanned. Normal, not an error. |
| `base_branch_not_default` | yes | The PR does not target the default branch. `message` names both branches. |
| `pull_request_not_found` | yes | The provider has no such PR. Suspect your own arguments. |
| `awaiting_webhook` | **no** | PR is open, non-draft, targets the default branch, and there is still no record. `retryAfterSeconds: 30`. The only reason that indicates a fault on Dam Secure's side. |

For non-GitHub repositories (Azure DevOps, Bitbucket), the draft /
base-branch / not-found distinctions cannot be enriched, so those PRs report the
less specific `awaiting_webhook` instead. Treat a persistent `awaiting_webhook`
on a non-GitHub repo as "unknown", not as a confirmed fault.

### `notRescannedReason` — why results are for a different commit

| Value | Meaning |
|---|---|
| `scan_trigger_on_pr_open` | The organisation scans only when a PR opens. The open-time scan stands; later commits are never rescanned. Arrives with `status: complete` and `retryAfterSeconds: null` — a **complete** answer, not a stale one. |

---

## Issue shape

```json
{
  "issueId": "…",
  "title": "…",
  "description": "…",
  "severity": "critical",
  "status": "open",
  "source": "vulnerability",
  "cwe": ["CWE-89"],
  "confidence": "high",
  "projectName": "api",
  "lens": "…",
  "reachableFrom": "…",
  "authorityPath": "…",
  "defensesChecked": "…",
  "attackScenario": "…",
  "severityRationale": "…",
  "recommendation": "…",
  "findings": [
    {
      "findingId": "…",
      "findingSummary": "…",
      "filePath": "packages/api/src/x.ts",
      "startLine": 42,
      "relevantCode": "…",
      "explanation": "…",
      "evidenceEntries": [
        { "filePath": "…", "startLine": 1, "relevantCode": "…", "reasoning": "…" }
      ],
      "supportingRefs": [
        { "filePath": "…", "startLine": 1, "relevantCode": "…", "reasoning": "…" }
      ]
    }
  ]
}
```

| Field | Notes |
|---|---|
| `issueId` | `issues_v2` UUID. Accepted by `get_issue`, `confirm_issue`, `dismiss_issue`. |
| `severity` | `critical` / `high` / `medium` / `low` / `info`. Drives the sort order. |
| `status` | Triage status: `open` / `acknowledged` / `dismissed`. An already-dismissed issue is someone's recorded decision — weigh it, don't re-raise it as new. |
| `source` | `vulnerability` (Dam Secure's rules) or `team` (a rule this customer wrote). Both are real findings. |
| `cwe` | Zero or more CWE identifiers. |
| `confidence` | The scanner's confidence. Pair with `severity` when ranking. |
| `projectName` | Which project inside the repository. `null` for single-project repos. |
| `lens` | Which vulnerability-review lens produced it. |
| `reachableFrom`, `authorityPath`, `defensesChecked` | Reachability and existing-mitigation analysis. Useful for arguing a finding is or isn't exploitable in context. |
| `attackScenario` | Concrete exploit path. The highest-signal field for real-world risk. |
| `severityRationale` | Why this severity. Quote it rather than re-deriving. |
| `recommendation` | Suggested remediation. |
| `findings[]` | One entry per location. Never empty for a returned issue. |

### Finding shape

| Field | Notes |
|---|---|
| `findingId` | UUID. Accepted by `confirm_finding`, `dismiss_finding`, `fix_finding`, `restore_finding` (all require `mcp:write`). |
| `findingSummary` | One-line description of this occurrence. |
| `filePath`, `startLine` | Location. May be `null`; handle that rather than assuming a line number. |
| `relevantCode` | The offending snippet, as scanned. |
| `explanation` | Why the rule fired here. |
| `evidenceEntries` | Supporting locations that establish the vulnerability. |
| `supportingRefs` | Related context that is not itself the vulnerability. |

Every string field on an issue or finding **except `title`** may be `null`.
Guard your formatting accordingly.

---

## Worked examples

### Clean — the only safe all-clear

```json
{ "status": "complete", "retryAfterSeconds": null,
  "scan": { "scannedHeadSha": "a1b2c3d", "isCurrent": true, "notRescannedReason": null },
  "pendingScan": null,
  "summary": { "totalIssues": 0, "returnedIssues": 0, "truncated": false },
  "issues": [] }
```

`complete` + `isCurrent: true` + `issues: []` → **no issues on this commit.** Say so.

### Mid-scan, previous commit's findings available

```json
{ "status": "running", "retryAfterSeconds": 30,
  "scan": { "scannedHeadSha": "9f8e7d6", "isCurrent": false, "notRescannedReason": null },
  "pendingScan": { "scanId": "…", "status": "running", "startedAt": "…" },
  "summary": { "totalIssues": 2, "returnedIssues": 2, "truncated": false },
  "issues": [ /* 2 issues from 9f8e7d6 */ ] }
```

A scan of your commit is in flight. The two issues are real but from the
**previous** commit. Either sleep 30s and re-call, or act on them now while
naming `9f8e7d6`. Do not present them as results for the commit under test.

### Terminal, results from an earlier commit by policy

```json
{ "status": "complete", "retryAfterSeconds": null,
  "scan": { "scannedHeadSha": "0011223", "isCurrent": false,
            "notRescannedReason": "scan_trigger_on_pr_open" },
  "pendingScan": null,
  "issues": [ /* findings from PR-open */ ] }
```

**Stop polling.** This organisation scans at PR open only. Report the findings
and name the commit. `retryAfterSeconds: null` is the instruction.

### Nothing coming, and that is fine

```json
{ "status": "not_scanned", "reason": "draft_pull_request",
  "retryAfterSeconds": null, "scan": null, "pendingScan": null, "issues": [] }
```

Terminal and normal. Report "not scanned — draft pull request". **Not** an error,
and **not** clean.

### Nothing coming, and that is a problem

```json
{ "status": "not_scanned", "reason": "awaiting_webhook",
  "retryAfterSeconds": 30, "scan": null, "pendingScan": null, "issues": [] }
```

Poll to your deadline. If it never resolves, report **unavailable** and flag that
webhook delivery or ingestion may be broken — this is the one reason that is
Dam Secure's fault.

---

## Error results

The tool returns an MCP error result (rather than a status) for caller mistakes:

- A missing or malformed `repository` — it must be the `owner/repo` slug.
- A missing or non-integer `prNumber`.

Unexpected server-side failures are caught at the tool boundary and returned as a
generic error result — deliberately free of internal ids, paths, or SQL. A GitHub
outage does **not** produce an error result: it degrades to
`not_scanned` / `awaiting_webhook` so a provider hiccup never looks like a
security answer.

Fix your arguments on an error result. Do not retry an identical failing call,
and never fall back to reporting the PR as clean.
