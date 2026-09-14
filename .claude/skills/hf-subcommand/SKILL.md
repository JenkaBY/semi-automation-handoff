---
name: hf-subcommand
description: Add or change a subcommand of the hf CLI in this plugin repository. Use this whenever work touches plugins/handoff/scripts/cmd/, adds a new hf verb, changes an existing one's flags or output, or when someone says "add a command to hf", "hf should also be able to…", or asks why a new command is not showing up in the help. Registering a subcommand means five places, and forgetting the mock or the CLI reference produces tests that silently pass while agents cannot discover the command.
---

# Adding a subcommand to `hf`

Subcommands are **sourced**, not executed: `scripts/hf.sh` loads every `lib/*.sh`, then
sources `cmd/<name>.sh`. So a subcommand uses `exit`, has all library functions already in
scope, and must never re-source a library itself.

## The five places

Miss one and the command half-exists. In particular the CLI reference is what *agents* read
to discover commands — a command absent from it may never be called at all.

1. `plugins/handoff/scripts/cmd/<name>.sh` — the implementation.
2. The usage block in `plugins/handoff/scripts/hf.sh` — human discovery.
3. `plugins/handoff/skills/handoff-protocol/references/cli.md` — agent discovery. One table
   row: command, purpose, output shape.
4. `plugins/handoff/tests/run.sh` — at least one check of the happy path and one of the
   failure you care about.
5. `plugins/handoff/tests/mock/gh` — only if the command calls a GitHub endpoint the mock has
   not seen. See the `gh-mock` skill.

## The shape of a cmd script

```bash
# hf <name> --ref REF --thing VALUE
# One sentence on what it does and, if it is not obvious, why it exists.
# Output: <name><TAB>field<TAB>field

ref=""; thing=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ref) ref="$2"; shift 2 ;;
    --thing) thing="$2"; shift 2 ;;
    *) hf_die "$HF_EX_CONFIG" "<name>: unknown argument $1" ;;
  esac
done

hf_gh_require          # skip only for commands that never touch the network
hf_config_load         # add --required when the command is useless without config
hf_ref_required "$ref" # prints "→ owner/repo#42" so the human sees what resolved

# ... work ...

printf '<name>\t%s\t%s\n' "$a" "$b"
exit 0
```

Exit codes live in `lib/log.sh` and carry meaning for the calling agent: `2` bad arguments,
`3` environment precondition, `4` graph violation, `5` protocol mismatch, `6` not found,
`7` ambiguous state needing a human, `75` conflict after retries. Reuse them rather than
inventing new numbers — the skills document these and agents branch on them.

## Rules the existing commands follow

- **Go through `lib/gh.sh`.** A raw `gh` call inside a cmd script is invisible to the mock,
  and the offline suite stops covering that path.
- **Print TSV, one line per record.** An agent reads this output; prose costs tokens.
- **Never print an empty TSV field.** Tab is IFS whitespace, so two tabs in a row collapse on
  `read` and shift every later column. Emit `—` (or `-` in a jq filter) and convert back.
- **Editing an existing comment goes through `hf_comment_update_optimistic`** with a mutator
  that touches only your own part and a verifier that checks meaning, not bytes. Writing a
  comment body directly reintroduces the lost-update race the protocol is built to avoid.
- **Reuse `hf_resolve_ref`** so the command accepts every reference form for free.

## Verify

```bash
bash -n plugins/handoff/scripts/cmd/<name>.sh
bash plugins/handoff/tests/run.sh
bash plugins/handoff/scripts/hf.sh --help | grep <name>
```

If the command writes to GitHub, also try it once against a real repository you own before
calling it done — the mock proves the logic, not the API contract.
