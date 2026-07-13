# Dam Secure Skills

Reusable skills for AI coding agents, published by Dam Secure. Each skill is an
[Agent Skills](https://agentskills.io) `SKILL.md` — a single portable format that
both **Claude Code and Cursor** read natively. The only thing that differs per
editor is which directory the skill is installed into.

## Install

Pick your editor. The one-liner below installs each skill's entry points for
both editors in the current project; the per-editor options are narrower.

### Claude Code (recommended: versioned plugin marketplace)

```
/plugin marketplace add dam-secure/damsecure-skills
/plugin install secure-spec-setup@damsecure
```

Updates via `/plugin marketplace update damsecure`. (No script runs — Claude
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

The installer only **copies markdown** into your editor's skills directory:

| Editor | Directory it reads |
|--------|--------------------|
| Claude Code | `.claude/skills/<name>/` |
| Cursor | `.cursor/skills/<name>/` |

Then open your editor there and ask it to "set up Secure Spec", or invoke
`/secure-spec-setup` directly. Both editors also support global install via
`--scope user` (`~/.claude/skills`, `~/.cursor/skills`).

## Available skills

| Skill | What it does | Claude | Cursor |
|-------|--------------|:------:|:------:|
| `secure-spec-setup` | Guided [Secure Spec](https://docs.damsecure.ai/secure-spec/installation) onboarding — finds your plans directory, installs the CLI, sets `plan-dirs`, and connects the MCP server. | ✅ | ✅ |

_(Each new skill ships as its own installable unit.)_

## Why one SKILL.md works everywhere

`SKILL.md` (YAML frontmatter `name` + `description`, then a markdown body) is the
open Agent Skills standard, read by both Claude Code and Cursor. The
`secure-spec-setup` skill is editor-aware in the two steps that differ (post-install
reload, MCP auth) and tells the agent to follow the row for the editor it's running
in — so the same file drives both.

## Layout

```
.claude-plugin/
  marketplace.json          # Claude Code marketplace: lists every plugin
plugins/
  secure-spec-setup/        # Claude plugin form of the skill
    .claude-plugin/plugin.json
    skills/secure-spec-setup/
      SKILL.md              # the portable, editor-aware skill (source of truth)
      discover-plans.md     # subagent brief for plan discovery
install.sh                  # copies a skill into the Cursor/Claude skills dirs
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

Contribution is restricted to Dam Secure employees — see
[`CONTRIBUTING.md`](CONTRIBUTING.md). This repo distributes code that runs on
customer machines; report vulnerabilities per [`SECURITY.md`](SECURITY.md).
`main` is protected (PR + review + CI). Details in
[`docs/security-hardening.md`](docs/security-hardening.md).
