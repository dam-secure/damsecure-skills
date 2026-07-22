# Remediation loop — per-finding playbook

Detailed reference for Steps 3–5 of `SKILL.md`. Work the worklist top to bottom,
one `pending` finding at a time. This is **interactive**: the confirm / dismiss /
fix decision is the user's, and every code change needs their approval before you
apply it.

## The loop, per finding

### 1. Bring the finding into context

- Pull the finding's detail. Reuse what you cached in Step 2; if you need more,
  `get_issue id=<issueId>` (with `branch=` if branch-scoped). Note: `get_issue`
  returns the **whole issue** (all its findings) — work only the `findingId` this
  row is about.
- Note the rule, why it fired, the severity, and the exact `file:line`.
- **Read the real code** at that location — the finding's line plus enough
  surrounding context to understand data flow (where the tainted input comes
  from, where the sink is). Don't reason from the finding text alone.

### 2. Decide with the user: genuine or not?

Present it plainly: the rule, the location, the code, and *why* it fired. Then
get the user's verdict. Three outcomes:

- **Genuine vulnerability** → `confirm_finding issueId=… findingId=…`, then go to
  step 3 and fix it.
- **False positive** (the rule misread the code) → `dismiss_finding` with a `note`
  saying why, or `dismiss_issue` with `dismissalReason=false_positive` if the
  whole issue is a false positive. Mark the row `dismissed`. Skip to the next.
- **Real but won't fix now** (accepted risk, out of scope, compensating control)
  → dismiss with `dismissalReason=wont_fix` or `accepted_risk` and a `note`, or
  leave `open` and mark the row `skipped` if the user wants to revisit. Their
  call — surface the trade-off, don't decide it.

Finding-level vs issue-level: triage **per finding** when findings in one issue
deserve different verdicts (one real, one false positive). Use the **issue-level**
shortcut (`confirm_issue` / `dismiss_issue`) only when the whole issue is
uniformly right or wrong.

### 3. Propose and apply the fix

- Design a **minimal, root-cause** fix — parameterize the query, encode the
  output, swap the weak primitive for a strong one, add the missing authz check.
  Not a broad refactor. Prefer the repo's existing helpers and patterns; match
  surrounding style.
- **Show the diff and explain it** before touching anything: what changes, why it
  closes the finding, and any behavior change it implies.
- **Apply only after the user approves.** If they want a different approach, adjust
  and re-propose. Security fixes can alter behavior — the user owns that decision.
- If one fix resolves several findings (same root cause, multiple locations),
  say so and handle them together — but still `fix_finding` each `findingId`
  individually.

### 4. Verify before marking fixed

Don't call `fix_finding` on faith. Confirm the change is real and safe:

- Re-read the edited code; confirm the vulnerable pattern is gone and the
  root cause (not just the symptom line) is addressed.
- Run what the repo provides — build, type-check, linter, the relevant tests. If
  there's a test that exercises the path, run it; if there isn't and the fix is
  non-trivial, offer to add one.
- If verification fails, fix forward before proceeding — a broken build is not a
  fixed finding.

### 5. Mark fixed and advance

- `fix_finding issueId=… findingId=…`.
- Update the worklist row: `status=fixed`, check the box.
- Move to the next `pending` row. Every few findings, give a one-line progress
  update (`4 fixed, 1 dismissed, 2 to go`).

## Verdict → tool cheat-sheet

| User's verdict | Code change? | MCP call | Worklist status |
|----------------|:------------:|----------|-----------------|
| Genuine, fix it now | yes | `confirm_finding` → (edit) → `fix_finding` | `fixed` |
| False positive | no | `dismiss_finding note=…` (or `dismiss_issue false_positive`) | `dismissed` |
| Won't fix / accepted risk | no | `dismiss_finding` / `dismiss_issue` `wont_fix`\|`accepted_risk` + note | `dismissed` |
| Real, defer | no | leave `open` | `skipped` |
| Changed my mind after triage | — | `restore_finding` | back to `pending` |

## Handling the enumeration with a subagent (large scopes)

When Step 2 has many issues, keep the main context clean by dispatching a
subagent to enumerate:

> "For each of these issue IDs [...], call `get_issue` and return a compact list:
> issueId, findingId, severity, rule, file:line, and the one-line reason each
> finding fired. Return only that structured list — no prose."

Then you write the worklist yourself from its return. Do the *fixing* in the main
session, though — remediation needs the full repo context and the user in the loop.

## Guardrails (repeat of the ones that bite here)

- **Fix before you mark fixed.** `fix_finding` is the last step, post-verification.
- **`fix_finding` ≠ re-scanned.** It's your triage verdict; the scanner re-validates
  on the next push/PR. Say so at close-out.
- **Approval per edit.** No silent code changes.
- **One finding's fix shouldn't break another.** Re-verify after multi-location fixes.
