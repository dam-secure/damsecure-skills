# Dam Secure Skills

A Claude Code **plugin marketplace** for Dam Secure. Add it once, then install whichever skills you want.

## Use it

```
/plugin marketplace add dam-secure/damsecure-skills
/plugin                                       # browse the menu and pick
```

Or install a specific plugin directly:

```
/plugin install secure-spec-setup@damsecure
```

Update later with `/plugin marketplace update damsecure`.

> Local checkout? `/plugin marketplace add /path/to/damsecure-skills`.

## Available skills

| Plugin | What it does |
|--------|--------------|
| `secure-spec-setup` | Guided [Secure Spec](https://docs.damsecure.ai/secure-spec/installation) onboarding — discovers your plans directory, installs the CLI, sets `plan-dirs`, and connects the MCP server. |

_(More to come — each new skill ships as its own installable plugin.)_

## Layout

```
.claude-plugin/
  marketplace.json          # the marketplace: lists every plugin
plugins/
  secure-spec-setup/        # one plugin = one installable unit
    .claude-plugin/plugin.json
    skills/secure-spec-setup/
      SKILL.md
      discover-plans.md
docs/design.md
```

## Add a new skill

1. Create `plugins/<skill-name>/`.
2. Add `plugins/<skill-name>/.claude-plugin/plugin.json` (`name`, `description`, `version`, `author`, `keywords`).
3. Add the skill under `plugins/<skill-name>/skills/<skill-name>/SKILL.md` (plus any supporting files).
4. Append an entry to the `plugins` array in `.claude-plugin/marketplace.json` with `source: "./plugins/<skill-name>"`.

Each plugin is versioned independently, so users choose exactly what they install.

> **Bundling:** a single plugin may contain several related skills (put multiple dirs under its `skills/`). Prefer one-plugin-per-skill for maximum user choice; bundle only when skills are always used together.

## Why a marketplace?

A git-based plugin marketplace is Claude Code's first-party distribution mechanism — the same one the `damsecure` CLI uses internally. Users pull it with one command and pick individual plugins. The onboarding skill lives here (not inside the CLI's own plugin) on purpose: it guides the CLI install, so it must be obtainable before anything Dam Secure is on the machine.
