# Security Policy

## Why this repo is security-sensitive

`damsecure-skills` is a Claude Code plugin marketplace. Anything merged to `main`
can be pulled and executed on a customer's machine (skills instruct an agent;
the `damsecure-setup` skill runs `curl … | bash`). Treat `main` as a
release channel: a malicious or accidental change here is a supply-chain issue.

## Reporting a vulnerability

Please report privately; **do not open a public issue or PR**:

- Email **security@damsecure.ai**, or
- Use GitHub's **"Report a vulnerability"** (Security → Advisories) on this repo.

We aim to acknowledge within 2 business days.

## Controls on this repository

- `main` is protected: pull request + Code Owner approval + passing CI required;
  no direct pushes, force-pushes, or deletions.
- Write access is limited to Dam Secure employees; external forks cannot merge.
- Secret scanning with push protection, Dependabot alerts, and read-only default
  workflow permissions are enabled.
- GitHub Actions from fork pull requests require maintainer approval before they
  run.

See [`docs/security-hardening.md`](docs/security-hardening.md) for the full
control set and the org-owner follow-ups.
