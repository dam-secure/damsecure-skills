# Plan-discovery subagent brief

Dispatch a read-only subagent with this objective. Do not prescribe a step-by-step search procedure — state the goal and the required output and let the agent explore.

## Objective

Determine where implementation **plans / specs / design docs** live in the current repository, so Secure Spec can be pointed at the right directory. A "plan" is a structured markdown document describing intended work before it's built (a spec, RFC, proposal, design doc, or plan-mode output) — not source code, not a README, not changelogs or issue templates.

## Signals to weigh (strongest first)

Secure Spec's own detection treats these as strong, so rank them highly if present:

- Directories named `plans`, `specs`, `rfcs`, or `proposals` (at any depth).
- The subpaths `docs/plans/` or `.claude/plans/`.
- Files matching `*.plan.md` (Cursor plan-mode convention).
- Any other directory that in practice holds plan-shaped markdown (e.g. `design_docs/`, `docs/superpowers/plans/`, `docs/rfcs/`).

Only count markdown (`.md` / `.markdown`). Ignore `node_modules`, `dist`, `build`, `.git`, `vendor`, `testdata`, and similar non-source trees. A directory qualifies only if it actually contains plan-shaped documents, not just because its name matches.

## Required output

Return **only** this, nothing else:

1. A ranked list of up to 3 candidate directories (repo-relative paths), each with: a one-line reason, and how many plan-like markdown files it contains.
2. A single recommended default (the top candidate), or the explicit string `NONE` if the repo has no plausible plans directory.
3. If `NONE`: one sentence noting the repo will fall back to Secure Spec's built-in detection.

Keep it under ~150 words. Do not modify any files.
