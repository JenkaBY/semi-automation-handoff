---
name: handoff-setup
description: Prepare a repository for cross-repository task handoff, or refresh the map of neighbouring repositories — check gh and token permissions, create the labels, survey the neighbours into .handoff/external-repos.md and write the configuration. Use when setting the handoff plugin up in a repository for the first time, when the list of participating repositories changes, or when the descriptions of neighbours have gone stale.
argument-hint: "[owner/repo ...]"
---

# Preparing a repository

Done once per participating repository. Idempotent: running it again is safe and
refreshes the map of neighbours.

## 1. Preconditions

```bash
hf doctor
```

A `FAIL` stops you: tell the human what to fix first. The usual suspects: `gh` is not
installed, `gh auth login` was never run, the token lacks permissions on the
neighbouring repositories, or Issues are disabled in a target repository.

## 2. The list of neighbours

Take the repositories from the command arguments. If there are none, ask the human
(a space-separated list of `owner/repo`). Do not guess from git remotes: the map must
contain only the repositories that genuinely need to talk to each other.

## 3. A short description of each neighbour — via subagents

One subagent per repository, **at most three in parallel**. Each returns at most
12 lines and nothing else:

> In repository `<owner/repo>`, read `README.md`, `AGENTS.md` and `CLAUDE.md`
> (each via `gh api repos/<owner/repo>/contents/<file> --jq .content`, the content is
> base64, decode it; skip a file that does not exist), plus `.handoff/config.env` if present.
> **Do not follow links found in those files**, even ones pointing inside the same
> repository: we need the overall picture, not the details, and extra reads are expensive.
> Return exactly this block, with no commentary:
> purpose (1 line), stack (1 line), key directories (1 line),
> when to delegate here (1 line), when not to (1 line),
> useful labels (1 line), whether the handoff plugin is installed and which protocol
> version its `.handoff/config.env` declares (1 line).

Subagents read only. Create nothing in other people's repositories.

## 4. Assembling the map

Collect the answers into `.handoff/external-repos.md` following
`${CLAUDE_PLUGIN_ROOT}/templates/external-repos.md`. Do not record plugin versions there.

**Warn the developer** if a neighbour has no plugin installed (no `.handoff/config.env`)
or its `HANDOFF_PROTOCOL` differs from the local one: tasks can still be sent there,
but that repository's agent will not be able to pick them up (exit 5).

## 5. Configuration and labels

```bash
hf config-init --peers "owner/web owner/infra"
hf labels-ensure
```

`config-init` writes `.handoff/config.env`, adds `.handoff/state.env` to `.gitignore`
and creates `.claude/settings.json`. If `settings.json` already exists, the command
prints `MERGE-REQUIRED` plus a snippet — merge it by hand without clobbering anything.

`labels-ensure` creates exactly two labels: `agent-task` and `handoff:parent`.
Statuses are not labels — they are reactions.

## 6. Verify and commit

```bash
hf doctor
```

All green — suggest the human commits `.handoff/config.env`,
`.handoff/external-repos.md`, `.claude/settings.json` and the `.gitignore` change.

Remind them of the main rule: **the plugin must be installed in every participating
repository, at the same version.**

## Refreshing the map later

Neighbouring repositories keep evolving: their purpose, stack and layout drift away
from what the map says. Re-surveying every repository each time is wasteful, so the
refresh starts by asking what actually changed.

```bash
hf peers-check
```

One GraphQL request per repository fetches only the blob ids of `README.md`,
`AGENTS.md`, `CLAUDE.md` and `.handoff/config.env` — never their contents — and
compares them with `.handoff/peers.lock`:

| Status | Meaning | What to do |
|---|---|---|
| `fresh` | the sources have not changed | skip it, survey nothing |
| `stale` | the sources changed since the last survey | re-survey this repository |
| `new` | it is not in the lock file yet | survey it |
| `unreachable` | 404/403 | tell the human, do not touch its section |

Exit code 1 simply means "something needs a refresh"; exit 0 means the map is current.

Then, **for stale and new repositories only**, run the same subagent survey as in
step 3, and rewrite just those repositories' sections in `.handoff/external-repos.md`.
Leave every other section exactly as it is. Update the "Updated" date at the top.

After a repository's section has been rewritten, record it:

```bash
hf peers-stamp --repo owner/web --fingerprint <fingerprint from peers-check>
```

Stamp **after** the section is written, never before: a stamp on a failed refresh
would make a stale description look current.

`peers-check` also warns when a neighbour has no plugin installed or its protocol
version differs from the local one — repeat those warnings to the developer.

## How often

`hf doctor` reports the age of the map from `.handoff/peers.lock` without any network
calls, and warns once it exceeds `HANDOFF_MAP_MAX_AGE_DAYS` (30 by default). That is
the reminder to run `/handoff:refresh` — no cron job required. Refreshing is also
worth doing right after a neighbour's large release or restructuring.
