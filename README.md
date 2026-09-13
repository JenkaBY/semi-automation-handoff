# handoff — task handoff between GitHub repositories

*Русская версия документации: [docs/ru/](docs/ru/)*

A Claude Code plugin for semi-automatic task handoff between repositories.
Every repository carries its own skills and rules, so work is done better by the agent **inside** the target repository.
This plugin provides the transport, and the state
lives in GitHub itself: issues, comments and reactions. No external service.

```
/handoff:dispatch  →  parent task + context + tasks in neighbouring repositories
/handoff:inbox     →  what arrived for me
/handoff:take      →  picked it up, working on it
/handoff:report    →  done, here is the result — task closed
/handoff:block     →  a human is needed, asking a question
/handoff:check     →  how the delegated tasks are doing
/handoff:answer    →  answering the assignee, lifting the block
/handoff:accept    →  the chain is finished — closing the parent task
```

## Quick start

```bash
# 1. in every participating repository
/plugin marketplace add jenkaBY/semi-automation-handoff@v0.3.0
/plugin install handoff@handoff-marketplace

# 2. setup
/handoff:init owner/web owner/infra

# 3. work
/handoff:dispatch add the /v2/orders endpoint to the frontend
```

The plugin must be installed in **every** participating repository, at the same version.
For developing the plugin itself, the marketplace can be added from a local directory —
see [docs/en/setup.md](docs/en/setup.md).

## Documentation

| Document                                                 | About                                                |
|----------------------------------------------------------|------------------------------------------------------|
| [docs/en/setup.md](docs/en/setup.md)                     | token requirements, prerequisites, repository setup  |
| [docs/en/architecture.md](docs/en/architecture.md)       | flow, entities, integrity rules, deadlock protection |
| [docs/en/protocol.md](docs/en/protocol.md)               | message formats, statuses, conflict resolution       |
| [docs/en/usage.md](docs/en/usage.md)                     | scenarios and commands                               |
| [docs/en/troubleshooting.md](docs/en/troubleshooting.md) | exit codes and common problems                       |

The same documents in Russian live in [docs/ru/](docs/ru/).

## How it works

| Entity           | Where                                 | Who writes it                            |
|------------------|---------------------------------------|------------------------------------------|
| parent task      | initiating repository                 | orchestrator                             |
| result comment   | comment on the parent task            | result author, append-only               |
| routing comment  | one comment holding the status table  | the owner of each row                    |
| question comment | comment on the dependent task         | question and answer both live in it      |
| dependent task   | target repository, label `agent-task` | body — orchestrator, comments — assignee |

Four rules keep it consistent:

1. Status is a reaction on the task (👀 WIP, 😕 BLOCKED, 🚀 DONE, 👎 CANCELLED);
   the status table is a cache, rebuilt with `hf routing-render`.
2. A finished task is a closed task; the assignee closes it and the orchestrator does
   not judge quality.
3. A repository's table row is edited only by that repository's agent.
4. A question and its answer live in one comment; an answered question is marked 👍.

Code changes are linked to a task through the standard **Development** section —
`Closes #<number>` in the pull request body.

## Requirements

`gh` 2.40+ authenticated, bash (Git Bash on Windows, the system shell on Linux and macOS), git.
Token permissions: Issues, Contents and Pull requests — Read & Write, Metadata — Read,
on every participating repository. Details in [docs/en/setup.md](docs/en/setup.md).

## Tests

```bash
bash plugins/handoff/tests/run.sh
```

Offline, against a `gh` mock: row merging, optimistic locking, exhausted retries,
reaction-based statuses, the "question and answer in one comment" protocol, cycle and
depth protection, idempotency, reference parsing.

## Licence

MIT
