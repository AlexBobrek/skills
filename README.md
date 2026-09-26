# Skills

One source for the agent skills I use on all machines and in all projects.
Clone this repo once per machine, then run `install.sh` to link the skills
into Claude Code and Codex.

## Layout

```
README.md
install.sh
<family>/                  a group of skills from one source
  skills-lock.json         optional: upstream source + hash per skill
  <skill>/
    SKILL.md
    agents/openai.yaml     optional: Codex display metadata
    …                      other files the skill refers to
```

A **family** is a top-level directory. A **skill** is a directory in a family
that contains `SKILL.md`. Skills stay one level below their family, because
Claude Code and Codex do not search into subdirectories of a skills directory.

Current families:

| Family | Source |
| --- | --- |
| `matt-pocock-skills` | [mattpocock/skills](https://github.com/mattpocock/skills) |
| `pstack-skills` | [cursor/plugins pstack](https://github.com/cursor/plugins/tree/main/pstack), by [poteto](https://github.com/poteto) |

## Install on a machine

```bash
git clone <this repo> ~/Workspace/skills
~/Workspace/skills/install.sh
```

`install.sh` puts one symlink for each skill into `~/.claude/skills` and
`~/.codex/skills`:

```
~/.claude/skills/tdd  →  <repo>/matt-pocock-skills/tdd
~/.claude/skills/unslop  →  <repo>/pstack-skills/unslop
```

To use other target directories, give them as arguments:

```bash
./install.sh ~/.claude/skills ~/.agents/skills
```

To see the changes before they occur, set `DRY_RUN=1`.

The script is safe to run again. It:

- adds links for new skills
- removes links into this repo whose skill no longer exists
- does not touch other items in the target directory, so skills that are
  local to one machine can stay there
- stops if two families have a skill with the same name

Run `install.sh` again after each `git pull` that adds, removes or renames a
skill. A change to an existing skill needs no step, because the link points
at the files in this repo.

The installer reports the family for each new link, such as
`link unslop (pstack-skills)`.

## Add a family

1. Make a top-level directory, for example `my-skills/`.
2. Put each skill in it as `my-skills/<skill>/SKILL.md`.
3. If the skills come from another repo, keep a record of the source (for
   example a `skills-lock.json`) in the family directory.
4. Run `./install.sh`.

## Update `matt-pocock-skills` from upstream

`matt-pocock-skills/skills-lock.json` gives the upstream `skillPath` of each
skill. Upstream groups skills into category directories
(`skills/engineering/tdd`), but this repo keeps them flat
(`matt-pocock-skills/tdd`). To update, copy each upstream skill directory over
the one in this repo, then review the diff.
