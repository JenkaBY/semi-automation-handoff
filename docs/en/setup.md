# Installation and repository setup

*Русская версия: [../ru/setup.md](../ru/setup.md)*

## 1. GitHub token requirements

One token serves **all** participating repositories — your own and the neighbours'.
The plugin does not only file issues: it creates branches, pushes them and opens pull
requests, so issue permissions alone are not enough.

### Option A — fine-grained PAT (recommended)

*Settings → Developer settings → Personal access tokens → Fine-grained tokens.*

**Repository access:** choose "Only select repositories" and list **every**
participating repository. "Only current repository" will not do: the plugin writes to
the neighbours.

| Permission | Level | Why |
|---|---|---|
| **Issues** | Read & Write | issues, comments, labels, reactions, closing |
| **Contents** | Read & Write | reading neighbours' `README.md`/`AGENTS.md`/`CLAUDE.md`, creating branches, pushing |
| **Pull requests** | Read & Write | opening PRs and linking them to tasks through the Development section |
| **Metadata** | Read | mandatory alongside any other permission |

Nothing else needs to be enabled.

### Option B — classic PAT

| Repository set | Scope |
|---|---|
| at least one private | `repo` |
| all public | `public_repo` |

### Additional conditions

- **Account permissions in the repository.** A token grants capability, not authority.
  Closing tasks and pushing branches need **Write** access; issue-only work needs **Triage**.
- **Organisations with SAML SSO.** The token must be authorised for the organisation,
  otherwise `gh` returns 403 `Resource protected by organization SAML enforcement`.
- **Issues must be enabled** in every target repository:
  *Settings → General → Features → Issues*.
- **API budget:** 5000 requests per hour. A typical `/handoff:dispatch` across three
  repositories costs about 20 requests, `/handoff:inbox` costs one (GraphQL),
  `/handoff:check` about five. Below 200 remaining, `hf` warns you.
- **Token source.** `GH_TOKEN` and `GITHUB_TOKEN` take precedence over `gh auth login`.
  `hf doctor` prints which source is in use — check that first whenever permissions
  "look right" but you still get a 403.

### Verification

```bash
gh auth status
hf doctor
```

`gh auth status` shows scopes for classic tokens only. For fine-grained tokens
`hf doctor` checks permissions empirically: it calls each neighbour and distinguishes
403 (no permission) from 404 (no access to the repository).

## 2. Workstation prerequisites

| Requirement | Check | Note |
|---|---|---|
| `gh` 2.40+ | `gh --version` | https://cli.github.com |
| authenticated `gh` | `gh auth status` | `gh auth login` |
| bash | `bash --version` | Windows — Git Bash; Linux and macOS — the system shell |
| git | `git --version` | used to locate the repository root |

**Windows (Git Bash), Linux and macOS** are all supported. The plugin uses POSIX
utilities only, and GNU/BSD differences (`date` parsing, for example) are covered by
fallbacks. `jq` is not required: JSON is handled by the `--jq` built into `gh`, and the
local configuration is flat `KEY=VALUE`.

If `gh` is installed but invisible in PATH (common on Windows), the plugin finds it in
the usual install locations. A non-standard path goes into `HANDOFF_GH`:

```bash
export HANDOFF_GH="/c/Tools/gh/bin/gh.exe"      # Windows (Git Bash)
export HANDOFF_GH="/opt/gh/bin/gh"              # Linux / macOS
```

## 3. Installing the plugin

### From GitHub (the normal case)

In every participating repository:

```bash
/plugin marketplace add jenkaBY/semi-automation-handoff@v1.0.0
/plugin install handoff@handoff-marketplace
```

**The tag must be identical everywhere** — that is what guarantees matching versions.

### From a local copy (plugin development, or working without GitHub access)

A marketplace can be added straight from a directory on disk — point it at the root of
the plugin repository, where `.claude-plugin/marketplace.json` lives:

```bash
/plugin marketplace add /d/Workspace/semi-automation-handoff     # absolute path
/plugin marketplace add ../semi-automation-handoff               # relative path
/plugin install handoff@handoff-marketplace
```

Refresh after editing the local copy:

```bash
/plugin marketplace update handoff-marketplace
```

The same thing in a repository's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "handoff-marketplace": {
      "source": { "source": "directory", "path": "/d/Workspace/semi-automation-handoff" }
    }
  },
  "enabledPlugins": { "handoff@handoff-marketplace": true }
}
```

A `directory` path resolves against the repository's main checkout: when Claude Code
runs from a git worktree, the path still points at the main checkout.

A local path is a single-machine arrangement — it will not resolve for your colleagues.
Commit the GitHub variant to a shared repository:

```json
{
  "extraKnownMarketplaces": {
    "handoff-marketplace": {
      "source": { "source": "github", "repo": "jenkaBY/semi-automation-handoff" }
    }
  },
  "enabledPlugins": { "handoff@handoff-marketplace": true }
}
```

`/handoff:init` creates this file. If `settings.json` already exists, the command prints
a snippet for a manual merge and leaves your settings alone.

## 4. Preparing the repository

```
/handoff:init owner/web owner/infra
```

The command runs, in order:

1. `hf doctor` — preconditions. A red line stops the setup.
2. Subagents survey the neighbours: they read `README.md`, `AGENTS.md`, `CLAUDE.md`
   and `.handoff/config.env`, **without following links** from those files (token economy).
   At most three subagents in parallel, read-only.
3. Assembly of `.handoff/external-repos.md` — the map of neighbours, 12 lines each.
4. A warning if a neighbour has no plugin installed or its protocol version differs.
5. `hf config-init` — writes `.handoff/config.env`, adds `.handoff/state.env`
   to `.gitignore`, creates `.claude/settings.json`.
6. `hf labels-ensure` — creates the labels.
7. `hf doctor` again.

### What appears in the repository

| File | Committed | Purpose |
|---|---|---|
| `.claude/settings.json` | yes | auto-enables the marketplace and the plugin |
| `.handoff/config.env` | yes | neighbours, limits, label names |
| `.handoff/external-repos.md` | yes | the map of neighbours for the agent |
| `.handoff/peers.lock` | yes | fingerprints of the map sources, so a refresh knows what changed |
| `.handoff/state.env` | **no** | the session's current task, local state |

### Labels

Two of them, and neither carries status:

| Label | Why |
|---|---|
| `agent-task` | `/handoff:inbox` finds incoming tasks by it |
| `handoff:parent` | `/handoff:check` finds parent tasks by it |

Statuses are **not** labels — they are reactions (👀 WIP, 😕 BLOCKED, 🚀 DONE,
👎 CANCELLED). `gh` cannot filter by reactions, which is the only reason these two
labels exist.

## 5. Ready

Setup is complete when:

- `hf doctor` is green **in every** participating repository;
- plugin versions match (`hf version`);
- a trial `/handoff:dispatch` from repository A creates a task in repository B,
  and it shows up there in `/handoff:inbox`.

## 6. Keeping the map current

Neighbouring repositories evolve — purpose, stack and layout drift away from what
`.handoff/external-repos.md` says, and a stale map makes the orchestrator delegate to
the wrong place.

```
/handoff:refresh            # refresh what changed
/handoff:refresh --check    # only report what is stale, change nothing
```

The refresh is cheap because it asks what changed before surveying anything:
`hf peers-check` fetches one GraphQL response per repository containing only the blob
ids of `README.md`, `AGENTS.md`, `CLAUDE.md` and `.handoff/config.env`, and compares
them with `.handoff/peers.lock`. Subagents are then spent only on the repositories
marked `stale` or `new`; `fresh` ones are skipped entirely.

`hf doctor` shows the map's age from the lock file without any network call and warns
once it passes `HANDOFF_MAP_MAX_AGE_DAYS` (30 by default), so the reminder arrives on
its own. Refreshing is also worth doing right after a neighbour's big release.

`peers-check` doubles as a health check of the fleet: it reports a neighbour with no
plugin installed, and one whose protocol version has drifted from yours.
