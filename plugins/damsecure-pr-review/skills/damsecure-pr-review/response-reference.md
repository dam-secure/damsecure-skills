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
| `status` | enum | `complete` / `pending` / `running` / `failed` / `not_scanned` / `repository_not_found` / `invalid_request` |
| `reason` | enum \| null | Set on `not_scanned`, and also set to `awaiting_webhook` on some `pending` responses. Not a reliable proxy for `status`. See [Reasons](#reasons). |
| `message` | string | Human-readable summary. Safe to log or quote; contains no internal ids, paths, or SQL. |
| `pullRequest` | object \| null | See below. `null` on `repository_not_found` and `invalid_request`. |
| `retryAfterSeconds` | number \| null | `30` when re-calling can change the answer; `null` when the answer is final. **The only field the poll loop needs.** |
| `scan` | object \| null | The scan that produced `issues[]`. `null` = no scan has ever completed for this PR. |
| `pendingScan` | object \| null | Work still expected for the requested commit. `null` = nothing is coming. |
| `summary` | object \| null | Counts and truncation state. Non-null **exactly when `scan` is non-null** — guard before reading it. |
| `issues` | array | Describes **exactly the scan in `scan`**, whatever the `status`. `[]` when `scan` is `null`, and also when the scan found nothing. |

### `pullRequest`

| Field | Type | Notes |
|---|---|---|
| `number` | integer | The PR number you asked for. |
| `repository` | string | Resolved display name — `owner/repo` when Dam Secure recorded one, otherwise the bare repository name. |
| `repositoryId` | string | Dam Secure's UUID for the repository. Round-trips: pass it back as the `repositoryId` **parameter** to address this repository unambiguously. |
| `headRef` | string \| null | Source branch. Also the `branch` filter accepted by `list_issues` / `get_issue`. |
| `baseRef` | string \| null | Target branch. Dam Secure only scans PRs targeting the default branch. |
| `headSha` | string \| null | Head commit of the PR as Dam Secure last recorded it. Not necessarily the SHA you asked about. |
| `state` | string \| null | `open` / `closed`. |

The four nullable fields are all `null` together when Dam Secure holds no
`pull_requests` row for this PR — the `not_scanned` cases.

### `scan`

Describes **the scan whose findings are in `issues[]`** — which is not always a
scan of the commit you asked about.

| Field | Type | Notes |
|---|---|---|
| `scanId` | string | UUID of the scan. The only always-present field here. |
| `scannedHeadSha` | string \| null | The commit these findings were produced from. **Always report this alongside the findings.** |
| `isCurrent` | boolean \| null | `true` = matches your `headSha`. `false` = earlier commit. `null` = you omitted `headSha`, so staleness is unknowable. |
| `notRescannedReason` | enum \| null | `scan_trigger_on_pr_open` when results are deliberately not being refreshed. Otherwise `null`. |
| `startedAt` | ISO 8601 string \| null | Use for your own elapsed-time backoff. |
| `completedAt` | ISO 8601 string \| null | |

### `pendingScan`

| Field | Type | Notes |
|---|---|---|
| `scanId` | string \| null | `null` when `status` is `expected`, and whenever the PR row carries no scan id yet. |
| `status` | enum | `pending` (queued) / `running` (in progress) / `expected` (due for this commit, record not seen yet) |
| `startedAt` | ISO 8601 string \| null | `null` whenever `scanId` is, and when the scan row cannot be read. |

`pendingScan.status: "expected"` pairs with a top-level `status: pending` and
means Dam Secure knows a scan is due for this commit but the webhook has not
landed. Retryable.

### `summary`

`null` whenever `scan` is `null`. Check before dereferencing.

| Field | Type | Notes |
|---|---|---|
| `totalIssues` | integer | The **real** total for the scan, before capping. |
| `bySeverity` | object | `{ critical, high, medium, low, info }` — all five keys always present, counts over the real total. |
| `returnedIssues` | integer | How many are in `issues[]`. |
| `truncated` | boolean | `true` when `totalIssues` exceeded the 50-issue cap. Report the real total when true. |

`issues[]` is sorted **severity-descending** and capped at **50**, so a truncated
response gives you the 50 most severe — never a random subset.

---

## Reasons

### `reason` — why there is no scan record

Set on `status: not_scanned`. `awaiting_webhook` also appears alongside
`status: pending`, where a scan is expected but its record has not landed.

| Value | Terminal? | Meaning |
|---|:---:|---|
| `scans_disabled` | yes | PR scanning is off for this repository or organisation. |
| `draft_pull_request` | yes | Draft PRs are not scanned. Normal, not an error. |
| `base_branch_not_default` | yes | The PR does not target the default branch. `message` names both branches. |
| `pull_request_not_found` | yes | The provider has no such PR. Suspect your own arguments. |
| `awaiting_webhook` | **no** | No record, and nothing above explains it. `retryAfterSeconds: 30`. |

The four terminal reasons can still arrive with a previous commit's `scan` and
`issues[]` attached — a PR scanned before it was converted to draft, retargeted,
or had scanning switched off. Terminal describes the *retry*, not the payload.

**`awaiting_webhook` means "unknown", not "Dam Secure is broken".** It is the
diagnosis of last resort, returned whenever the ladder cannot do better:

- a genuine webhook gap — PR open, non-draft, targeting the default branch;
- a non-GitHub repository (Azure DevOps, Bitbucket), where the draft /
  base-branch / not-found distinctions cannot be enriched at all;
- GitHub install metadata missing from the repository record;
- the provider lookup itself erroring — a GitHub outage lands here rather than
  failing the call.

Only conclude webhook delivery or ingestion is broken in the first case. In the
others, report **unavailable** and leave the cause open.

### `notRescannedReason` — why results are for a different commit

| Value | Meaning |
|---|---|
| `scan_trigger_on_pr_open` | The organisation scans only when a PR opens. The open-time scan stands; later commits are never rescanned. Arrives with `status: complete` and `retryAfterSeconds: null` — a **complete** answer, not a stale one. |

---

## Issue shape

```json
{
  "id": "…",
  "title": "…",
  "description": "…",
  "severity": "critical",
  "severityRaw": "critical",
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
| `id` | `issues_v2` UUID. Accepted by `get_issue`, `confirm_issue`, `dismiss_issue`. **Not** `issueId` — only the finding identifier carries a suffix. |
| `severity` | `critical` / `high` / `medium` / `low` / `info`. Drives the sort order. Never null: an issue with no recorded severity reads as `info`. |
| `severityRaw` | The unnormalised column, `null` when nothing was recorded. Exists so Dam Secure's own blocking check can tell "explicitly info" from "no severity". You want `severity`. |
| `source` | `vulnerability` (Dam Secure's rules) or `team` (a rule this customer wrote). Both are real findings. |
| `cwe` | Zero or more CWE identifiers. **May be absent from the payload entirely**, not `null`. |
| `confidence` | The scanner's confidence. Pair with `severity` when ranking. |
| `projectName` | Which project inside the repository. `null` for single-project repos. |
| `lens` | Which vulnerability-review lens produced it. **May be absent from the payload entirely**, not `null`. |
| `reachableFrom`, `authorityPath`, `defensesChecked` | Reachability and existing-mitigation analysis. Useful for arguing a finding is or isn't exploitable in context. |
| `attackScenario` | Concrete exploit path. The highest-signal field for real-world risk. |
| `severityRationale` | Why this severity. Quote it rather than re-deriving. |
| `recommendation` | Suggested remediation. |
| `findings[]` | One entry per location. Never empty for a returned issue. |

**There is no triage-status field, by design.** The query behind `issues[]`
returns only active, failing, non-dismissed findings whose issue is itself
non-dismissed. Anything a human already dismissed — at either level — is gone
before you see it. Every returned issue is open; there is no state to weigh.

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

Guard your formatting: on an issue, every field except `id`, `title`, `source`,
`severity`, and `findings[]` may be missing or `null`; on a finding, everything
except `findingId`, `evidenceEntries`, and `supportingRefs`. Note the two
different flavours of absent — `cwe` and `lens` are omitted from the JSON when
unset, while the rest are explicitly `null`, so `issue.cwe?.length ?? 0` is safe
and `issue.cwe.length` is not.

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
  "retryAfterSeconds": 30, "scan": null, "pendingScan": null,
  "summary": null, "issues": [] }
```

Poll to your deadline. If it never resolves, report **unavailable**. Flag
possible webhook trouble only if the repository is GitHub-connected and the PR
is open, non-draft, and targeting the default branch — otherwise this is just
"unknown". Note `summary: null`, which pairs with `scan: null` on every
no-results response.

### Your call was malformed

```json
{ "status": "invalid_request", "reason": null,
  "message": "Provide only one of `repository` or `repositoryId`, not both.",
  "retryAfterSeconds": null, "pullRequest": null, "scan": null,
  "pendingScan": null, "summary": null, "issues": [] }
```

Nothing was looked up. Read `message`, fix the arguments, call again — once.
This is not a security result and re-sending the same call cannot help.

---

## Error results

Caller mistakes surface in two different shapes. Both set the MCP `isError`
flag; only one gives you a parseable body.

**Schema rejection — no body.** The argument never reaches the tool, so you get
a plain MCP validation error. This is what a missing or non-integer `prNumber`,
a non-positive `prNumber`, a `repositoryId` that isn't a UUID, or a `headSha`
outside `[0-9a-f]{7,40}` produces.

**`status: invalid_request` — full body, `isError` set.** The arguments parsed
but could not be used. Three causes, each named in `message`:

- neither `repository` nor `repositoryId` was supplied;
- both were supplied;
- a bare repository name matched more than one repository in your organisation.

Every other field is `null` or empty. Handle it in your status switch, not in a
catch block.

Unexpected server-side failures are caught at the tool boundary and returned as a
generic error string — deliberately free of internal ids, paths, or SQL. A GitHub
outage does **not** produce an error result: it degrades to
`not_scanned` / `awaiting_webhook` so a provider hiccup never looks like a
security answer.

Fix your arguments on either shape. Do not retry an identical failing call,
and never fall back to reporting the PR as clean.
