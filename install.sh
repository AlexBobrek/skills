#!/usr/bin/env bash
# Link every skill in every family of this repo into each agent's skills directory.
#
#   ./install.sh                 link into ~/.claude/skills and ~/.codex/skills
#   ./install.sh DIR [DIR...]    link into the given directories instead
#   DRY_RUN=1 ./install.sh       print what would change, change nothing
#
# A family is a top-level directory of this repo. A skill is a directory in a
# family that contains SKILL.md. Each skill is linked as <target>/<skill-name>.
#
# Safe to run again: correct links are left alone, links into this repo whose
# skill no longer exists are removed, and anything else in the target
# directory (real directories, links to other places) is never touched.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DRY_RUN="${DRY_RUN:-0}"

if [ "$#" -gt 0 ]; then
  TARGETS=("$@")
else
  TARGETS=("$HOME/.claude/skills" "$HOME/.codex/skills")
fi

run() {
  if [ "$DRY_RUN" = 1 ]; then echo "  (dry run) $*"; else "$@"; fi
}

# Collect skills as "name<TAB>family<TAB>absolute-path" so output shows
# which family supplied each link as this repo gains more sources.
skills="$(
  for skill_md in "$REPO"/*/*/SKILL.md; do
    [ -e "$skill_md" ] || continue
    dir="$(dirname "$skill_md")"
    printf '%s\t%s\t%s\n' "$(basename "$dir")" "$(basename "$(dirname "$dir")")" "$dir"
  done | sort
)"

if [ -z "$skills" ]; then
  echo "No skills found in $REPO/<family>/<skill>/SKILL.md" >&2
  exit 1
fi

# Two families must not have a skill with the same name: both would claim
# the same <target>/<name> link.
dupes="$(printf '%s\n' "$skills" | cut -f1 | uniq -d)"
if [ -n "$dupes" ]; then
  echo "Skill names used in more than one family:" >&2
  for name in $dupes; do
    printf '%s\n' "$skills" | awk -F'\t' -v n="$name" '$1 == n { print "  " $3 }' >&2
  done
  echo "Rename one of each pair, then run again." >&2
  exit 1
fi

for target in "${TARGETS[@]}"; do
  echo "$target"

  if [ -L "$target" ]; then
    echo "  is a symlink ($(readlink "$target")); expected a real directory. Skipped." >&2
    continue
  fi
  [ -d "$target" ] || run mkdir -p "$target"

  # Remove links into this repo whose skill is gone (deleted or renamed).
  for link in "$target"/*; do
    [ -L "$link" ] || continue
    dest="$(readlink "$link")"
    case "$dest" in
      "$REPO"/*)
        if [ ! -f "$dest/SKILL.md" ]; then
          echo "  remove stale  $(basename "$link")"
          run rm "$link"
        fi
        ;;
    esac
  done

  while IFS="$(printf '\t')" read -r name family src; do
    link="$target/$name"
    if [ -L "$link" ]; then
      current="$(readlink "$link")"
      if [ "$current" = "$src" ]; then
        continue
      fi
      case "$current" in
        "$REPO"/*)
          # Skill moved to another family in this repo.
          echo "  relink        $name ($family)"
          run ln -sfn "$src" "$link"
          ;;
        *)
          echo "  skip          $name (links to $current, not this repo)" >&2
          ;;
      esac
    elif [ -e "$link" ]; then
      echo "  skip          $name (a real file or directory is there)" >&2
    else
      echo "  link          $name ($family)"
      run ln -s "$src" "$link"
    fi
  done <<EOF
$skills
EOF
done
