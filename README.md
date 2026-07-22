# Dam Secure Skills

Reusable skills for AI coding agents, published by Dam Secure. Each skill is an
[Agent Skills](https://agentskills.io) `SKILL.md`, a single portable format that
both Claude Code and Cursor read natively. Only the install directory differs
per editor.

## Install

Pick your editor. The one-liner below installs each skill's entry points for
both editors in the current project; the per-editor options are narrower.

### Claude Code (recommended: versioned plugin marketplace)

```
/plugin marketplace add dam-secure/damsecure-skills
/plugin install damsecure-setup@damsecure
/plugin install damsecure-triage@damsecure
```

Updates via `/plugin marketplace update damsecure`. (No script runs; Claude
manages the plugin.)

### Cursor / Claude (copy the skill into your project)

```bash
curl -fsSL https://raw.githubusercontent.com/dam-secure/damsecure-skills/main/install.sh | bash
```

Or clone and run locally (no piping):

```bash
git clone https://github.com/dam-secure/damsecure-skills
./damsecure-skills/install.sh --tool cursor        # or: claude  / omit for both
./damsecure-skills/install.sh --scope user         # install globally (~/) instead of ./
```

The installer only copies markdown into your editor's skills directory:

| Editor | Directory it reads |
|--------|--------------------|
| Claude Code | `.claude/skills/<name>/` |
| Cursor | `.cursor/skills/<name>/` |

Then open your editor there and ask it to "set up Dam Secure", or invoke
`/damsecure-setup` directly. Both editors also support global install via
`--scope user` (`~/.claude/skills`, `~/.cursor/skills`).

## Available skills

| Skill | What it does | Claude | Cursor |
|-------|--------------|:------:|:------:|
| `damsecure-setup` | End-to-end [Dam Secure](https://docs.damsecure.ai/secure-spec/installation) onboarding: connect the CLI + MCP (Secure Spec plan review), onboard a repository, review and add rules, and triage PR and issue findings. | ✅ | ✅ |
| `damsecure-triage` | Remediation loop over your findings: pull them from the MCP into a local worklist, bring each into context, fix the code with you, mark it fixed, and move to the next — across a PR or the open backlog. | ✅ | ✅ |

_(Each new skill ships as its own installable unit. Install just one with
`./install.sh --skill damsecure-triage`.)_

## Why one SKILL.md works everywhere

`SKILL.md` (YAML frontmatter `name` + `description`, then a markdown body) is the
open Agent Skills standard, read by both Claude Code and Cursor. The
`damsecure-setup` skill is editor-aware in the two steps that differ (post-install
reload, MCP auth) and tells the agent to follow the row for the editor it's running
in, so the same file drives both.

## Layout

```
.claude-plugin/
  marketplace.json          # Claude Code marketplace: lists every plugin
plugins/
  damsecure-setup/          # onboarding skill (Claude plugin form)
    .claude-plugin/plugin.json
    skills/damsecure-setup/
      SKILL.md              # the portable, editor-aware skill (source of truth)
      discover-plans.md     # subagent brief for plan discovery
      triage.md             # detailed PR + issue triage flow reference
  damsecure-triage/         # findings remediation-loop skill
    .claude-plugin/plugin.json
    skills/damsecure-triage/
      SKILL.md              # the query → worklist → fix → mark-fixed loop
      remediation-loop.md   # per-finding remediation playbook
install.sh                  # copies skills into the Cursor/Claude skills dirs
docs/                       # design + security-hardening notes
```

## Add a new skill

1. Create `plugins/<skill-name>/.claude-plugin/plugin.json` and
   `plugins/<skill-name>/skills/<skill-name>/SKILL.md`.
2. Append it to the `plugins` array in `.claude-plugin/marketplace.json`
   (`source: "./plugins/<skill-name>"`).
3. Keep the `SKILL.md` editor-agnostic where behavior differs, so `install.sh`
   places one file that works in both editors.

## Contributing & security

Contribution is restricted to Dam Secure employees; see
[`CONTRIBUTING.md`](CONTRIBUTING.md). This repo distributes code that runs on
customer machines; report vulnerabilities per [`SECURITY.md`](SECURITY.md).
`main` is protected (PR + review + CI). Details in
[`docs/security-hardening.md`](docs/security-hardening.md).
