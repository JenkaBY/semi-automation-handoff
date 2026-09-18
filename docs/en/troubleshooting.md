# Troubleshooting

*Русская версия: [../ru/troubleshooting.md](../ru/troubleshooting.md)*

First move for any problem:

```bash
hf doctor
```

## `hf` exit codes

| Code | Meaning | What to do |
|---|---|---|
| 0 | success | — |
| 2 | configuration/argument error, or a precondition is unmet | fix the call; for "not in HANDOFF_PEERS" run `/handoff:init` |
| 3 | environment precondition failed | install/authenticate `gh`, create the labels |
| 4 | cycle or depth exceeded | do not delegate; ask via a BLOCKED question |
| 5 | protocol version mismatch | align the plugin version across repositories |
| 6 | entity not found | check the task reference |
| 7 | question has 👍 but no answer | stop, ask the human to append the answer |
| 75 | conflict unresolved after three attempts | BLOCKED plus `hf routing-render` |

## Common situations

### `gh: command not found` although GitHub CLI is installed

Typical on Windows: `gh` exists but Git Bash's PATH does not know about it. The plugin
looks in the standard places (Program Files, LOCALAPPDATA, `/usr/local/bin`, `/usr/bin`,
Homebrew on macOS and Linux). For a non-standard path:

```bash
export HANDOFF_GH="/c/Tools/gh/bin/gh.exe"
```

### 403 on a neighbouring repository

In order of likelihood:

1. The fine-grained token does not include that repository in Repository access.
2. A permission is missing: Issues — Read & Write, Contents — Read & Write,
   Pull requests — Read & Write.
3. The organisation uses SAML SSO and the token is not authorised for it.
4. A `GH_TOKEN`/`GITHUB_TOKEN` from a different account sits in the environment and
   overrides `gh auth login`. `hf doctor` prints the token source in use.

### 404 on a neighbouring repository

The repository is outside the token's reach. For private repositories, 404 is GitHub's
normal answer for "no access", not "does not exist".

### Tasks will not close, branches will not push

The account lacks repository access: code work needs **Write**, issue-only work needs
**Triage**. Token permissions alone are not enough.

### The status table disagrees with reality

The source of truth is the reactions on dependent tasks plus their open/closed state.
To restore:

```bash
hf routing-render --ref owner/api#42
hf check --ref owner/api#42
```

### Exit code 75 while writing a status

Several agents are editing the same routing comment. The status on the task is already
set, so nothing was lost. Mark the task BLOCKED, tell the human, then run
`hf routing-render`. Do not retry hopefully — the retry budget was spent deliberately.

### Exit code 7: 👍 is there but the answer is not

Somebody marked the question answered without appending the answer text. Work must not
resume: ask the human to append the answer to **that same** comment. A separate answer
comment is not part of the protocol and will not be found.

### `WARN peers-map` in doctor

The map of neighbours has not been refreshed for longer than
`HANDOFF_MAP_MAX_AGE_DAYS` (30 days by default), or `.handoff/peers.lock` does not
exist yet. Run `/handoff:refresh`; it re-surveys only the repositories whose
`README.md`, `AGENTS.md`, `CLAUDE.md` or `.handoff/config.env` actually changed.

`hf peers-check` exits with 1 whenever something needs a refresh — that is its
normal way of saying "there is work to do", not an error.

### A task does not show up in the inbox

1. `hf inbox --all` — it may already be closed, that is, finished.
2. Check for the `agent-task` label (added by `hf task-create`).
3. Check that `HANDOFF_LABEL_TASK` matches in both repositories' `.handoff/config.env`.

### `⚠no-PR` in the summary

The task is closed with no pull request linked. Either no code changed, or the PR body
is missing `Closes #<number>` — without that keyword GitHub does not show the PR in the
Development section.

### Duplicate tasks

They should not appear: one task per "chain + repository" pair, and a repeated
`task-create` returns `reused`. If a duplicate does exist, the tasks belong to different
chains. Mark the extra one CANCELLED and close it.

### Plugin versions have drifted

```bash
hf version    # in every repository
```

Bring every repository to the same marketplace tag:

```
/plugin marketplace add jenkaBY/semi-automation-handoff@v1.0.0
```

## Checking without a network

Row merging, optimistic locking, reaction-based statuses, the "question and answer in
one comment" protocol, cycle protection and idempotency are covered by offline tests
against a `gh` mock:

```bash
bash plugins/handoff/tests/run.sh
```
