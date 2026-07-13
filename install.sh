#!/usr/bin/env bash
# Install the Dam Secure "secure-spec-setup" skill for Claude Code and/or Cursor.
# The skill itself is a portable Agent Skills SKILL.md that both editors read —
# only the install directory differs:
#
#   Claude Code  ->  .claude/skills/<name>/
#   Cursor       ->  .cursor/skills/<name>/
#
# Usage:
#   ./install.sh                     # install for all editors, project scope
#   ./install.sh --tool cursor       # just Cursor (or: claude / claude,cursor)
#   ./install.sh --scope user        # install into ~/ (global) instead of ./
#
# Runnable from a clone, or piped:  curl -fsSL <raw>/install.sh | bash
set -euo pipefail

SKILL="secure-spec-setup"
REPO_RAW="https://raw.githubusercontent.com/dam-secure/damsecure-skills/main"
SRC_SUBPATH="plugins/${SKILL}/skills/${SKILL}"
FILES=("SKILL.md" "discover-plans.md")

TOOLS="claude,cursor"
SCOPE="project"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tool)  TOOLS="$2"; shift 2 ;;
    --scope) SCOPE="$2"; shift 2 ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Resolve the skill source: prefer a local checkout, else download to a tmp dir.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"
if [[ -n "$script_dir" && -f "$script_dir/$SRC_SUBPATH/SKILL.md" ]]; then
  SRC="$script_dir/$SRC_SUBPATH"
else
  SRC="$(mktemp -d)/$SKILL"; mkdir -p "$SRC"
  echo "Downloading skill from $REPO_RAW/$SRC_SUBPATH ..."
  for f in "${FILES[@]}"; do
    curl -fsSL "$REPO_RAW/$SRC_SUBPATH/$f" -o "$SRC/$f"
  done
fi

if [[ "$SCOPE" == "user" ]]; then base="$HOME"; else base="$(pwd)"; fi

# Map each tool to its skills root, de-duplicating shared dirs.
declare -a roots=()
add_root() { for r in "${roots[@]:-}"; do [[ "$r" == "$1" ]] && return; done; roots+=("$1"); }
IFS=',' read -ra selected <<< "$TOOLS"
for t in "${selected[@]}"; do
  case "$t" in
    claude) add_root "$base/.claude/skills" ;;
    cursor) add_root "$base/.cursor/skills" ;;
    *) echo "unknown tool: $t (expected claude or cursor)" >&2; exit 2 ;;
  esac
done

for root in "${roots[@]}"; do
  dest="$root/$SKILL"
  mkdir -p "$dest"
  for f in "${FILES[@]}"; do cp "$SRC/$f" "$dest/$f"; done
  echo "✔ installed -> ${dest/#$HOME/~}"
done

echo
echo "Done. Open your editor in this location and ask it to \"set up Secure Spec\","
echo "or invoke the skill directly (Claude/Cursor: /secure-spec-setup)."
echo "Claude Code users can alternatively use the versioned plugin marketplace:"
echo "  /plugin marketplace add dam-secure/damsecure-skills"
echo "  /plugin install secure-spec-setup@damsecure"
