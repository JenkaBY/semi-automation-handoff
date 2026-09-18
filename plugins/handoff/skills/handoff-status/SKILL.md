---
name: handoff-status
description: Keep track of tasks delegated to other GitHub repositories — status summary, answers to blocked assignees, and closing the parent task once the whole chain is finished. Use when you need to know how delegated work is progressing or to close a chain.
argument-hint: "[ref]"
---

# Keeping track of delegated tasks

Protocol: `${CLAUDE_PLUGIN_ROOT}/skills/handoff-protocol/SKILL.md`.

Nobody's work is judged here. A closed dependent task counts as finished —
the protocol has no acceptance step.

## 1. Summary

```bash
hf check                 # all open parent tasks
hf check --ref <ref>     # just one
```

Output: a `PARENT` line, one line per target repository (task, status, date,
linked PRs, question), then `SUMMARY`.

| Flag | Meaning | Action |
|---|---|---|
| `⟲stale-table(X→Y)` | the reaction on the task disagrees with the table | `hf check --ref <ref> --render` |
| `⏳stalled(Nd)` | WIP or BLOCKED is not moving | tell the human, do not act yourself |
| `⚠no-PR` | the task is closed but no PR is linked | ask whether any code changed |
| `⚠no-access` | the token cannot read the task | `hf doctor` |

The source of truth is the reaction on the task; the table is a cache. A mismatch is
fixed by rebuilding the table, never by editing tasks.

## 2. Answering a blocked assignee

BLOCKED means a human is needed. The question link sits in the Question column.

1. Show the human the question text.
2. Get their answer. Never answer on their behalf about priorities, deadlines, money
   or compatibility — those are decisions, not work.
3. Write the answer to a file and run:

```bash
hf answer --ref <question url> --body-file <file>
```

The answer is appended **to that same comment**, 👍 appears on it, and the task goes
back to NEW. A separate answer comment is never created.

## 3. Closing the chain

```bash
hf accept --ref <parent task>
```

The command closes the parent task only when nothing is BLOCKED and every dependent
task is finished (DONE or CANCELLED). Otherwise it refuses and lists what is left —
that is a normal outcome, not an error: wait for the assignees.

`--force` closes despite unfinished work. Use it only when the human explicitly asks,
and tell them exactly what was left open.

## 4. Cancelling a task

If a task is no longer needed, give it 👎 CANCELLED:

```bash
hf status-set --ref <repo#N> --status CANCELLED
```

Table rows are never deleted — cancelled work stays visible.
