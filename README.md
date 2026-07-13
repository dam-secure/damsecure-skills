# Secure Spec Onboarding

A Claude Code **plugin marketplace** that ships one skill — `secure-spec-setup` — which walks you through installing and connecting [Dam Secure Secure Spec](https://docs.damsecure.ai/secure-spec/installation).

## Install

In Claude Code, add this repo as a marketplace and install the plugin:

```
/plugin marketplace add dam-secure/secure-spec-onboarding
/plugin install secure-spec-setup@secure-spec-onboarding
```

Then run the skill:

```
/secure-spec-setup
```

or just ask Claude to "set up Secure Spec".

> Prefer a local checkout? Clone this repo and run
> `/plugin marketplace add /path/to/secure-spec-onboarding` instead of the GitHub shorthand.

## What the skill does

1. **Reviews where plans live** — dispatches a subagent to find your repo's plans/specs directory (read-only).
2. **Installs the CLI** — runs `curl -fsSL https://app.damsecure.ai/resources/cli/install.sh | bash` (with your confirmation), which authenticates the CLI and installs the Secure Spec plugin.
3. **Confirms the plans directory** — you approve the discovered directory (or supply your own); the skill persists it with `damsecure plan-dirs set`.
4. **Connects the MCP server** — triggers the `damsecure` MCP OAuth prompt directly, then verifies the connection.

After setup, saving an implementation plan under your configured directory triggers Secure Spec's automatic security review.

## Why a plugin marketplace?

A git-based plugin marketplace is Claude Code's first-party distribution mechanism — the same one the `damsecure` CLI uses internally. It's the most widely used way to share a skill: users pull it with two commands, and updates arrive via `/plugin marketplace update`. This skill is distributed **separately from the CLI on purpose** — it guides the CLI install, so it must be obtainable before anything Dam Secure is on the machine.

## Layout

```
.claude-plugin/
  marketplace.json          # marketplace metadata + plugin list
  plugin.json               # the secure-spec-setup plugin manifest
skills/
  secure-spec-setup/
    SKILL.md                # the five-step walkthrough
    discover-plans.md       # subagent brief for plan discovery
docs/
  design.md                 # design notes / spec
```
