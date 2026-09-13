# Status model

Status is stored as a **reaction on the task body**. Labels are never used for status.

| Code | Emoji | GitHub reaction | Who sets it |
|---|---|---|---|
| NEW | ⬜ | *no reactions* | default on creation; `hf answer` when a block is lifted |
| WIP | 👀 | 👀 `eyes` | assignee |
| BLOCKED | ⛔ | 😕 `confused` | assignee |
| DONE | 🚀 | 🚀 `rocket` + issue closed | assignee |
| CANCELLED | 👎 | 👎 `-1` | orchestrator |

**Why DONE is 🚀 and not 💯.** GitHub allows exactly eight reactions
(👍 👎 😄 🎉 😕 ❤️ 🚀 👀); 💯 is not one of them.

**Resolution order** when several reactions are present: CANCELLED → DONE →
*issue closed* → BLOCKED → WIP → NEW. A closed issue counts as finished even
without a reaction.

👍 `+1` is not a status: it marks a question comment as answered.

## Transitions

```
NEW ──take──▶ WIP ──report──▶ DONE (the assignee closes the task)
 ▲             │
 │             └──block──▶ BLOCKED ──answer──▶ NEW
 └─────────────────────────────────┘

Parent task: closed by the orchestrator (hf accept) once nothing is BLOCKED
and every dependent task is finished (DONE or CANCELLED).
```

- The assignee sets WIP, BLOCKED, DONE (and closes its own task).
- The orchestrator lifts blocks by answering, cancels tasks, closes the parent task.
- There is no acceptance step: the orchestrator does not judge code quality.

## What nobody does

- The assignee never edits its task body or anyone else's row.
- The orchestrator never edits result comments — they are append-only.
- Nobody deletes table rows: cancelled work is marked CANCELLED.
- Nobody opens a separate comment to answer a question.
