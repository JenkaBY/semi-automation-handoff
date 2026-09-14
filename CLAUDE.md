# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A Claude Code plugin (`plugins/handoff`) plus the marketplace that serves it. The plugin
hands tasks between GitHub repositories: state lives in GitHub issues, comments and
reactions — there is no server, no database and no background process. Read
[docs/en/architecture.md](docs/en/architecture.md) before changing the protocol.

## Commands

```bash
bash plugins/handoff/tests/run.sh          # the whole offline suite (no network, gh is mocked)
hf doctor                                  # environment diagnostics against real GitHub
bash plugins/handoff/scripts/hf.sh --help  # every subcommand, when hf is not on PATH
```

`run.sh` has no name filter: it is one script, and every block sets up and tears down its
own sandbox. To debug a single command, reproduce a block by hand:

```bash
export PATH="plugins/handoff/tests/mock:$PATH"     # shadow gh with the mock
export HF_MOCK_DIR=$(mktemp -d) HANDOFF_ROOT=$(mktemp -d) HF_NO_SLEEP=1 HF_DEBUG=1
mkdir -p "$HANDOFF_ROOT/.handoff" && printf 'HANDOFF_REPO=owner/api\nHANDOFF_PEERS="owner/web"\n' > "$HANDOFF_ROOT/.handoff/config.env"
bash plugins/handoff/scripts/hf.sh inbox --repo owner/web
```

`HF_DEBUG=1` prints retry and conflict decisions; `HF_NO_SLEEP=1` removes the backoff waits;
`HANDOFF_GH` points at a `gh` binary outside PATH.

## Architecture

`hf.sh` sources every `scripts/lib/*.sh`, then sources `scripts/cmd/<name>.sh` — subcommands
are *sourced*, not executed, so they use `exit` and share the loaded libraries.

The layering that matters:

- **`lib/gh.sh` is the only place that touches the network.** Everything else goes through
  it, which is exactly why the test suite can shadow `gh` in PATH and run fully offline.
  Adding a raw `gh` call inside a `cmd/` script breaks that property.
- **`lib/status.sh` owns the status vocabulary.** Status is a *reaction* on the issue body
  plus its open/closed state — never a label. `hf_status_resolve` is the single place where
  several reactions collapse into one status.
- **`lib/table.sh` merges one row at a time.** The routing comment is a cache; a row belongs
  to one repository's agent and every other row is copied through byte for byte.
- **`lib/retry.sh` implements the only safe way to edit a comment**: read version → mutate
  your part → re-read version → PATCH → verify → at most three attempts → exit 75.
- **`lib/peers.sh`** fingerprints the sources of `.handoff/external-repos.md` so a refresh
  re-surveys only what changed.

The skills in `plugins/handoff/skills/` carry the prose contract; `commands/` are thin
wrappers that delegate to them. Deterministic logic belongs in bash, not in prompts —
that is the project's main lever on token cost.

## Conventions that will bite you

- **No `jq`.** It is absent on Windows by default. JSON is parsed by `gh --jq`; local config
  is flat `KEY=VALUE` (`.handoff/config.env`).
- **POSIX only, with GNU/BSD fallbacks.** Windows (Git Bash), Linux and macOS are all
  supported. `date` parsing goes through `hf_date_epoch`; hashing falls back
  `sha1sum` → `shasum` → `cksum`. No `sed -i` in runtime code, no associative arrays.
- **Never emit an empty TSV field.** Tab is IFS whitespace, so consecutive tabs collapse on
  `read` and silently shift every column after them. Emit a placeholder (`—`, or `-` in jq
  output) and translate it back after reading. This has already caused one real bug.
- **Line endings are pinned to LF** by `.gitattributes`. A CRLF shebang does not execute in
  Git Bash, WSL or on Linux.
- **Output stays compact.** Subcommands print TSV, one line per record, because an agent
  reads them and every line costs tokens.
- **Comment markers are protocol, not decoration.** `<!-- handoff:routing -->`,
  `<!-- handoff:result -->`, `<!-- handoff:question -->` and the `### 💬 Answer` heading are
  matched by `grep`/`jq` filters in several scripts and in the mock. Changing one means
  changing all of them plus the tests.

## Adding a subcommand

1. `scripts/cmd/<name>.sh` — parse flags with a `while/case` loop, call `hf_gh_require` and
   `hf_config_load`, `exit` with a code from `lib/log.sh`.
2. Add it to the usage block in `scripts/hf.sh`.
3. Add a row to `skills/handoff-protocol/references/cli.md` (this is what agents read).
4. Cover it in `tests/run.sh`.
5. If it calls a GitHub endpoint the mock has never seen, teach `tests/mock/gh` that
   endpoint — the mock emulates `gh` *after* `--jq`, so it prints what the real pipeline
   would print, not raw JSON.

## Documentation is bilingual

`docs/en/` and `docs/ru/` are mirrors; English is the working language of the code and the
skills. Any change to a string the plugin writes into GitHub — table headers, comment
headings, summary flags — must land in both, and usually in `plugins/handoff/templates/`
too. The only Russian text allowed outside `docs/ru/` is the "Русская версия" link at the
top of each English document.

To find untranslated text, search by UTF-8 lead bytes — `grep -P '[А-Яа-я]'` silently
matches nothing in the C locale:

```bash
LC_ALL=C grep -rn $'[\xd0\xd1]' --exclude-dir=.git --exclude-dir=ru .
```

## Versions

Two independent numbers:

- **Protocol** (`HANDOFF_PROTOCOL`, `metadata.protocolVersion`) — the wire contract. A task
  whose major protocol differs from the local one is refused with exit 5. Bump it only for a
  breaking change to issue bodies, the table or the markers.
- **Plugin version** — lives in *two* files that must agree:
  `plugins/handoff/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`.
  Install instructions in `README.md` and both `docs/*/setup.md` pin a tag, so a release also
  updates `@vX.Y.Z` there and adds a `CHANGELOG.md` entry.

## Project skills

`.claude/skills/` holds four skills for maintaining this repository. They load
automatically and can also be invoked by name:

| Skill | Reach for it when |
|---|---|
| `hf-subcommand` | adding or changing an `hf` verb — registering one means five places |
| `handoff-release` | bumping the version — it lives in two manifests and five documents |
| `handoff-i18n` | touching docs or any string the plugin writes into GitHub |
| `gh-mock` | a test needs an endpoint the mock has never seen |

## Commits

Conventional Commits, grouped by meaning — one commit per group, not one per file. The body
explains why the group exists, not what the diff already shows.
