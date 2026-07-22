#!/usr/bin/env bash
# Install Dam Secure skills for Claude Code and/or Cursor.
# Each skill is a portable Agent Skills SKILL.md that both editors read;
# only the install directory differs:
#
#   Claude Code  ->  .claude/skills/<name>/
#   Cursor       ->  .cursor/skills/<name>/
#
# Usage:
#   ./install.sh                          # all skills, all editors, project scope
#   ./install.sh --skill damsecure-triage # just one skill (comma-separate for several)
#   ./install.sh --tool cursor            # just Cursor (or: claude / claude,cursor)
#   ./install.sh --scope user             # install into ~/ (global) instead of ./
#
# Runnable from a clone, or piped:  curl -fsSL <raw>/install.sh | bash
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/dam-secure/damsecure-skills/main"

# Skills this installer knows about, and the files each one ships.
ALL_SKILLS="damsecure-setup,damsecure-triage"
skill_files() {
  case "$1" in
    damsecure-setup)  echo "SKILL.md discover-plans.md triage.md" ;;
    damsecure-triage) echo "SKILL.md remediation-loop.md" ;;
    *) echo "unknown skill: $1" >&2; return 2 ;;
  esac
}

SKILLS="$ALL_SKILLS"
TOOLS="claude,cursor"
SCOPE="project"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill) SKILLS="$2"; shift 2 ;;
    --tool)  TOOLS="$2"; shift 2 ;;
    --scope) SCOPE="$2"; shift 2 ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"
if [[ "$SCOPE" == "user" ]]; then base="$HOME"; else base="$(pwd)"; fi

# Map each tool to its skills root, de-duplicating shared dirs.
declare -a roots=()
add_root() { for r in "${roots[@]:-}"; do [[ "$r" == "$1" ]] && return; done; roots+=("$1"); }
IFS=',' read -ra selected_tools <<< "$TOOLS"
for t in "${selected_tools[@]}"; do
  case "$t" in
    claude) add_root "$base/.claude/skills" ;;
    cursor) add_root "$base/.cursor/skills" ;;
    *) echo "unknown tool: $t (expected claude or cursor)" >&2; exit 2 ;;
  esac
done

# Resolve one skill's source: prefer local checkout, else download to a tmp dir.
resolve_src() {
  local skill="$1"; shift
  local files=("$@")
  local subpath="plugins/${skill}/skills/${skill}"
  if [[ -n "$script_dir" && -f "$script_dir/$subpath/SKILL.md" ]]; then
    echo "$script_dir/$subpath"
  else
    local tmp; tmp="$(mktemp -d)/$skill"; mkdir -p "$tmp"
    echo "Downloading $skill from $REPO_RAW/$subpath ..." >&2
    for f in "${files[@]}"; do
      curl -fsSL "$REPO_RAW/$subpath/$f" -o "$tmp/$f"
    done
    echo "$tmp"
  fi
}

IFS=',' read -ra selected_skills <<< "$SKILLS"
for skill in "${selected_skills[@]}"; do
  read -ra files <<< "$(skill_files "$skill")"
  src="$(resolve_src "$skill" "${files[@]}")"
  for root in "${roots[@]}"; do
    dest="$root/$skill"
    mkdir -p "$dest"
    for f in "${files[@]}"; do cp "$src/$f" "$dest/$f"; done
    echo "✔ installed $skill -> ${dest/#$HOME/~}"
  done
done

echo
echo "Done. Open your editor in this location and ask it to \"set up Dam Secure\""
echo "or \"triage my Dam Secure findings\", or invoke a skill directly"
echo "(Claude/Cursor: /damsecure-setup, /damsecure-triage)."
echo "Claude Code users can alternatively use the versioned plugin marketplace:"
echo "  /plugin marketplace add dam-secure/damsecure-skills"
echo "  /plugin install damsecure-setup@damsecure"
echo "  /plugin install damsecure-triage@damsecure"
