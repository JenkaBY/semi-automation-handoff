# Concurrency, conflicts and freedom from deadlocks

## Optimistic locking when editing comments

`hf routing-set`, `hf routing-render` and `hf answer` (which appends into an existing
question comment) all run the same protocol:

1. `GET` the comment → body and `updated_at` (the version).
2. The mutator changes **only its own part** — its table row, or the tail of the
   question; everything else is carried over byte for byte.
3. `GET` again: the version moved → start over.
4. `PATCH`.
5. Verify with `GET`: the change is in place.
6. If not, back off 1s/2s/4s with jitter and retry. Three attempts at most.

## What to do on exit code 75

The retry budget is spent. The agent does exactly this:

1. Do not write again — the budget is gone.
2. The status on the task itself (the reaction) is already set and is the source of
   truth, so no system state was lost.
3. Mark the task BLOCKED and tell the human who is competing for the routing comment,
   with a link to it.
4. Suggest `hf routing-render --ref <parent task>` — it rebuilds the table from reactions.

## What to do on exit code 7

`hf question-status` returned `reacted-no-answer`: the question comment carries 👍 but
holds no answer text. That is a contradiction, not a race. Do not resume the task,
leave it BLOCKED, and ask the human to append the answer to that same comment.

## Freedom from deadlocks

- **No synchronous waiting.** No command waits on another repository; everything is
  discovered by polling (`/handoff:check`, `/handoff:inbox`).
- **Cycles are refused.** Task metadata carries `path: owner/a>owner/b`.
  Creating a task in a repository already on the path is refused (exit 4).
  Need something from an ancestor? That is a BLOCKED question, not a new task.
- **Depth is capped** by `HANDOFF_MAX_DEPTH` (3 by default).
- **Idempotency.** One task per "chain + repository" pair: a repeated `task-create`
  updates the existing task (`reused`) instead of creating a duplicate.
- **Stalling is visible.** `/handoff:check` flags WIP and BLOCKED older than
  `HANDOFF_STALE_DAYS` with ⏳ — a signal for the human, never an automatic action.

## The rule for any uncertainty

Stop, set BLOCKED, describe the situation to a human. No guessing about someone else's
repository, and no hopeful retries.
