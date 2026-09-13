# Architecture

*Русская версия: [../ru/architecture.md](../ru/architecture.md)*

## Why

Every repository carries its own skills, rules and knowledge of its own architecture.
A task is done better and cheaper by the agent **inside** the target repository than by
an initiating agent reaching into unfamiliar code from outside. What is needed is
transport between repositories — and GitHub itself carries the state: issues, comments,
reactions. No external service, no shared database, no background processes.

## Flow

```
Repository A (orchestrator)                    Repository B (assignee)
───────────────────────────                    ───────────────────────
changes committed on a branch
  (git status clean — otherwise we ask the human)
  │
/handoff:dispatch
  │
  ├─ parent task  #42 ◀── may have been filed by a human beforehand
  │    ├─ 📦 result comment      ← THE ONLY carrier of context
  │    └─ 🔀 routing comment     ← table: repository → status → question
  │
  └─ creates ────────────────────────────────▶ dependent task #17
                                                 label: agent-task
                                                 body: context link,
                                                       routing comment link,
                                                       meta (chain, path, protocol)
                                                          │
                                               /handoff:inbox → /handoff:take
                                                          │  reaction 👀
                                                          │  branch + work + PR (Closes #17)
                                            ┌─────────────┴─────────────┐
                                        finished                   human needed
                                            │                           │
                                   /handoff:report              /handoff:block
                                  🚀 + task CLOSED               😕 question comment
                                            │                           │
       /handoff:check ◀── rows are updated by the assignees             │
            │                                                          │
            │                            /handoff:answer ──────────────┘
            │                    the answer is appended to that same comment,
            │                    👍 appears on it, status goes back to NEW
            ▼
       /handoff:accept ──▶ nothing blocked and all dependents closed → close the parent task
```

## Entities

| Entity | Where | Who writes it | How to find it |
|---|---|---|---|
| parent task | initiating repository | orchestrator only | label `handoff:parent` |
| result comment | comment on the parent task | result author, append-only | marker `<!-- handoff:result -->` |
| routing comment | exactly one comment on the parent task | the owner of each row | marker `<!-- handoff:routing -->` |
| question comment | comment on the dependent task | question by assignee, answer appended into it | marker `<!-- handoff:question -->` |
| dependent task | target repository | body — orchestrator, comments — assignee | label `agent-task` |

## Four integrity rules

1. **Status is a reaction on the task**, plus its open/closed state. The routing table
   is a cache; it can always be rebuilt (`hf routing-render`), so a failed write to the
   table never loses system state. This is the main defence against races.
2. **A finished task is a closed task.** The assignee closes it. The orchestrator does
   not judge quality: closed means done.
3. **Row ownership.** A repository's row is edited only by that repository's agent.
4. **Append-only wherever possible.** Results are new comments. The one edit of an
   existing comment is the answer appended into a question, and it is guarded by
   optimistic locking.

## Freedom from deadlocks

- No synchronous waiting: no command waits on another repository.
- Cycles are refused: a task carries `path: owner/a>owner/b`, and a repository
  appearing on the path twice is rejected (exit 4). Information from an ancestor is
  requested with a blocking question, never with a task flowing backwards.
- Depth is capped by `HANDOFF_MAX_DEPTH`.
- Stalled tasks are flagged in `/handoff:check`, but nothing happens automatically.
- Any uncertainty ends as BLOCKED plus a question to a human — including the
  "👍 present, answer missing" contradiction (exit 7).

## Token economy

| Technique | Where |
|---|---|
| deterministic logic in bash rather than in prompts | `scripts/lib/*` |
| compact TSV output instead of JSON dumps | every `hf` subcommand |
| one GraphQL request for the whole inbox with statuses | `hf inbox` |
| one request per task instead of three (status + PRs + dates) | `hf_issue_facts` |
| thin SKILL.md files with references behind links | `skills/handoff-protocol/references/` |
| hard length limits in the templates | `templates/` |
| context is never re-told, only linked | `templates/task-body.md` |
| `init` subagents do not follow links out of README/AGENTS/CLAUDE | `skills/handoff-setup` |

## Cross-platform support

Windows (Git Bash), Linux and macOS. POSIX utilities only; GNU/BSD differences are
covered by fallbacks (`date`, `sha1sum`/`shasum`); `jq` is not required; `gh` is
discovered outside PATH in the usual install locations.

## Boundaries

- There are no triggers: an assignee learns about a task from `/handoff:inbox` or a
  GitHub notification. Hence "semi-automatic".
- One task per "chain + repository" pair. A second task for the same repository means
  a new parent task, that is, a new chain.
- The plugin never changes code in other repositories and never commits on the
  developer's behalf: with an unclean tree, `dispatch` stops and asks.
