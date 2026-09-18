---
name: handoff-protocol
description: The handoff cross-repository task protocol — GitHub entities, reaction-based statuses, write-ownership rules and conflict resolution. Background knowledge for the handoff-dispatch, handoff-inbox, handoff-status and handoff-setup skills.
user-invocable: false
---

# The handoff protocol

State lives in GitHub itself. There is no server and no shared database.

## Four entities

| Entity | Where | Who writes it |
|---|---|---|
| **parent task** | initiating repository, label `handoff:parent` | the orchestrator only |
| **result comment** | comment on the parent task, append-only | whoever produced the result |
| **routing comment** | exactly one comment holding the status table | the owner of each row |
| **dependent task** | target repository, label `agent-task` | body — orchestrator, comments — assignee |

## Four rules everything rests on

1. **Status is a reaction.** Labels never carry status: 👀 WIP, 😕 BLOCKED,
   🚀 DONE, 👎 CANCELLED, no reactions — NEW. There are only two labels and neither
   is a status: `agent-task` and `handoff:parent`, used where `gh` can filter.
2. **A finished task is a closed task.** The assignee closes it in `report`.
   The orchestrator neither reviews quality nor "accepts": closed means done.
3. **Row ownership.** A repository's row in the routing comment is edited only by
   that repository's agent. The source of truth is the reaction on the task itself;
   the table is a cache and can always be rebuilt (`hf routing-render`).
4. **A question and its answer are one comment.** The answer is appended to the
   question comment and the responder marks it 👍. If 👍 is there but no answer is,
   stop the work and call a human. Once the answer is read, the assignee clears the
   question link from its own row.

## Code changes and pull requests

Code is linked to a task through the standard **Development** section: the pull request
body carries `Closes #<task number>`. Branch links never clutter comments or the table.

## Saving context

- A task prompt **never re-tells** the work already done — it links to the result comment.
- Read the references below when you need them, not all at once.
- `hf …` output is already compact (TSV) — show the human the conclusion, not the dump.

## References

- Statuses, reactions and transitions: [references/status-model.md](references/status-model.md)
- Concurrency, conflicts, deadlock protection: [references/concurrency.md](references/concurrency.md)
- `hf` commands, arguments and exit codes: [references/cli.md](references/cli.md)
- Terms: [references/glossary.md](references/glossary.md)

## Templates

`${CLAUDE_PLUGIN_ROOT}/templates/`: `parent-issue.md`, `result-comment.md`, `task-body.md`,
`question.md`, `external-repos.md`. Read the one you are filling in right now.
