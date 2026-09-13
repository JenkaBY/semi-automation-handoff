# Working with handoff

*Русская версия: [../ru/usage.md](../ru/usage.md)*

## Handing part of the work to neighbours

`dispatch` is orchestration; it changes no code. The precondition is that the changes
the task builds on are already committed on a development branch.

```bash
git status --porcelain    # must be empty
```

If anything is uncommitted or untracked, the agent stops and asks: commit or revert.
Commits follow the format this repository uses; if none is declared, changes are grouped
by meaning and committed group by group with Conventional Commits messages
(`feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`).

```
/handoff:dispatch add the /v2/orders endpoint to the frontend and ship the migration
```

On top of an existing issue filed by a human:

```
/handoff:dispatch 42 …
/handoff:dispatch owner/api#42 …
/handoff:dispatch https://github.com/owner/api/issues/42 …
```

## Picking a task up

```
/handoff:inbox
/handoff:take 17
```

`take` adds 👀, pulls the requester's context and starts the work on a dedicated branch.

## Reporting

Before reporting, the changes are opened as a pull request whose body says `Closes #17`:
that is how the PR lands in the task's Development section.

```
/handoff:report
/handoff:report 17 short note on what was done
```

`report` publishes the result comment, adds 🚀 and **closes the task**.

## Asking a question and pausing

```
/handoff:block 17 which date format does the response use — ISO or unix?
```

The question is posted as a comment, the task gets 😕, and the question link appears in
the Question column of the routing comment. Work stops.

## Checking, answering, finishing

```
/handoff:check
/handoff:answer owner/web#9 ISO-8601 in UTC
/handoff:accept owner/api#42
```

`answer` appends the answer **to the same question comment** and adds 👍 to it.
`accept` closes the parent task once nothing is blocked and every dependent task is closed.

## Resuming a blocked task

```bash
hf question-status --ref <question url>
```

| Result | What to do |
|---|---|
| `pending` | no answer yet — wait |
| `answered` | the answer is printed right there — carry on |
| `reacted-no-answer` | 👍 present, answer missing — stop and ask a human |

Once you resume, clear the link: `hf status-set --ref 17 --status WIP --clear-question`.

## Keeping the map of neighbours current

Repositories evolve, and a stale `.handoff/external-repos.md` sends work to the wrong
place. The refresh only re-surveys what actually changed:

```
/handoff:refresh            # refresh the repositories whose sources changed
/handoff:refresh --check    # report what is stale, change nothing
/handoff:refresh owner/web  # just this one
```

`hf doctor` warns once the map is older than `HANDOFF_MAP_MAX_AGE_DAYS` (30 by default),
so you do not have to remember the cadence yourself.

## Task references

Every command accepts a reference in any form:

| Form | Example |
|---|---|
| plain number | `42` |
| number with a hash | `#42` |
| repository and number | `owner/api#42` |
| issue URL | `https://github.com/owner/api/issues/42` |
| comment URL | `…/issues/42#issuecomment-123` |
| the session's current task | omit it, or `-` |

The first output line says what was resolved: `→ owner/api#42`.

## A day in the life

| Role | Morning | During the day | Before wrapping up |
|---|---|---|---|
| orchestrator | `/handoff:check` | `/handoff:answer` on blocks | `/handoff:accept` once everything is closed |
| either role | `/handoff:refresh` when doctor warns the map is stale | — | — |
| assignee | `/handoff:inbox` | `/handoff:take`, the work, the PR | `/handoff:report` or `/handoff:block` |

## What the plugin will not do

- Commit uncommitted changes without the developer's decision.
- Judge the quality of someone else's work: a closed task counts as finished.
- Decide on deadlines, priorities, money or compatibility for a human — it files a
  BLOCKED question instead.
- Retry a write after three conflicts — it goes BLOCKED and asks for help.
- Create tasks in repositories missing from `.handoff/config.env`.
