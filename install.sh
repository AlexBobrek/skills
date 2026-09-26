#!/usr/bin/env bash
# Link every skill in every family of this repo into each agent's skills directory.
#
#   ./install.sh                 link into ~/.claude/skills and ~/.codex/skills
#   ./install.sh DIR [DIR...]    link into the given directories instead
#   DRY_RUN=1 ./install.sh       print what would change, change nothing
#
# For the standard Claude and Codex targets, also sync default-skills.txt into
# a managed block in ~/.claude/CLAUDE.md and ~/.codex/AGENTS.md.
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

# Every listed default must have an installable skill. Validate before writing.
defaults=()
while IFS= read -r name || [ -n "$name" ]; do
  case "$name" in ''|'#'*) continue ;; esac
  if [[ ! "$name" =~ ^[a-z0-9][a-z0-9-]*$ ]] ||
     ! printf '%s\n' "$skills" | cut -f1 | grep -Fxq "$name"; then
    echo "Invalid or missing default skill: $name" >&2
    exit 1
  fi
  for existing in "${defaults[@]+"${defaults[@]}"}"; do
    if [ "$existing" = "$name" ]; then
      echo "Duplicate default skill: $name" >&2
      exit 1
    fi
  done
  defaults+=("$name")
done < "$REPO/default-skills.txt"

sync_defaults() {
  local file="$1" agent="$2" skills_dir="$3" start end starts ends tmp name expected link mode
  start='<!-- skills-repo defaults:start -->'
  end='<!-- skills-repo defaults:end -->'

  for name in "${defaults[@]+"${defaults[@]}"}"; do
    expected="$(printf '%s\n' "$skills" | awk -F'\t' -v n="$name" '$1 == n { print $3 }')"
    link="$skills_dir/$name"
    if [ -L "$link" ]; then
      if [ "$(readlink "$link")" != "$expected" ]; then
        echo "Default skill link points elsewhere: $link" >&2
        return 1
      fi
    elif [ -e "$link" ] || [ "$DRY_RUN" != 1 ]; then
      echo "Default skill link is unavailable: $link" >&2
      return 1
    fi
  done

  if [ -L "$file" ]; then
    echo "Refusing to edit symlinked instructions: $file" >&2
    return 1
  fi
  starts=0; ends=0
  if [ -f "$file" ]; then
    starts="$(grep -Fxc "$start" "$file" || true)"
    ends="$(grep -Fxc "$end" "$file" || true)"
  fi
  if [ "$starts" -ne "$ends" ] || [ "$starts" -gt 1 ]; then
    echo "Malformed managed block in $file" >&2
    return 1
  fi

  if [ "$DRY_RUN" = 1 ]; then
    tmp="$(mktemp)"
  else
    tmp="$(mktemp "$(dirname "$file")/.skills-repo.XXXXXX")"
  fi
  if [ -f "$file" ]; then
    # Keep existing instructions, remove the old block and trailing blank lines.
    awk -v start="$start" -v end="$end" '
      $0 == start { managed = 1; next }
      $0 == end { managed = 0; next }
      !managed {
        if ($0 ~ /^[[:space:]]*$/) { blanks = blanks "\n"; next }
        printf "%s%s\n", blanks, $0
        blanks = ""
      }
    ' "$file" > "$tmp"
  fi

  if [ "${#defaults[@]}" -gt 0 ]; then
    [ ! -s "$tmp" ] || printf '\n' >> "$tmp"
    printf '%s\n' "$start" '## Default skills' >> "$tmp"
    if [ "$agent" = codex ]; then
      printf '%s\n' 'At the start of every task, read each skill below. Apply its rules before every response:' >> "$tmp"
      for name in "${defaults[@]+"${defaults[@]}"}"; do
        printf '%s\n' "- $skills_dir/$name/SKILL.md" >> "$tmp"
      done
    else
      printf '%s\n' 'Apply these skill rules before every response:' >> "$tmp"
      for name in "${defaults[@]+"${defaults[@]}"}"; do
        printf '%s\n' "@$skills_dir/$name/SKILL.md" >> "$tmp"
      done
    fi
    printf '%s\n' "$end" >> "$tmp"
  fi

  if [ -f "$file" ] && cmp -s "$tmp" "$file"; then
    rm "$tmp"
    return
  fi
  echo "  update defaults $file"
  if [ "$DRY_RUN" = 1 ]; then
    rm "$tmp"
  else
    # Keep existing file permissions and replace the file only after rendering.
    if [ -f "$file" ]; then
      mode="$(stat -f %Lp "$file" 2>/dev/null || stat -c %a "$file")"
      chmod "$mode" "$tmp"
    else
      chmod 644 "$tmp"
    fi
    mv "$tmp" "$file"
  fi
}

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

  case "$target" in
    "$HOME/.claude/skills") sync_defaults "$HOME/.claude/CLAUDE.md" claude "$target" ;;
    "$HOME/.codex/skills") sync_defaults "$HOME/.codex/AGENTS.md" codex "$target" ;;
  esac
done
