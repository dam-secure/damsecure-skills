# Contributing

This repository is **open source (readable and forkable by anyone) but
contribution is restricted to Dam Secure employees.** It distributes code that
customers install and run inside their editors, so the integrity of `main` is a
supply-chain control, not just a code-quality one.

## Who can contribute

- **Dam Secure employees** with write access, added via the org (never as
  individual outside collaborators).
- Everyone else may open issues and fork the repo, but pull requests from forks
  **cannot be merged**; they exist for transparency, not for landing changes.

## How changes land

1. Branch from `main` (no direct pushes; `main` is protected).
2. Open a pull request. CI must pass and a **Code Owner** (see
   [`.github/CODEOWNERS`](.github/CODEOWNERS)) must approve.
3. Squash-merge. Force-pushes and branch deletion on `main` are blocked.

## Adding or changing a skill

See the "Add a new skill" section in [`README.md`](README.md). Each skill is its
own plugin under `plugins/<name>/`. Keep `SKILL.md` accurate to the real product
behavior; a wrong instruction here runs on a customer's machine.

## Reporting a security issue

Do **not** open a public issue. See [`SECURITY.md`](SECURITY.md).
