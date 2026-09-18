# Message protocol

*Русская версия: [../ru/protocol.md](../ru/protocol.md)*

Protocol version: **1**. The major version must match across every participating
repository; on a mismatch the task is never picked up (exit code 5).

## Statuses are reactions

Labels never carry status.

| Code | Emoji | GitHub reaction | Who sets it |
|---|---|---|---|
| NEW | ⬜ | *no reactions* | default on creation; `hf answer` when a block is lifted |
| WIP | 👀 | 👀 `eyes` | assignee |
| BLOCKED | ⛔ | 😕 `confused` | assignee |
| DONE | 🚀 | 🚀 `rocket`, issue closed | assignee |
| CANCELLED | 👎 | 👎 `-1` | orchestrator |

GitHub allows only eight reactions (👍 👎 😄 🎉 😕 ❤️ 🚀 👀) and 💯 is not one of them,
which is why DONE is 🚀.

**Resolution order** when several reactions are present:
CANCELLED → DONE → *issue closed* → BLOCKED → WIP → NEW.
A closed issue counts as finished even without a reaction: a finished task is a closed task.

👍 `+1` is not a status: it marks a question comment as answered.

## Lifecycle

```
NEW ──take──▶ WIP ──report──▶ DONE (the assignee closes its own task)
 ▲             │
 │             └──block──▶ BLOCKED ──answer──▶ NEW
 └─────────────────────────────────┘
```

There is no acceptance step: the orchestrator does not judge code quality. Once nothing
is blocked and every dependent task is finished, the orchestrator closes the parent task
(`hf accept`).

## Routing comment

```markdown
<!-- handoff:routing v=1 chain=hf-20260913-a1b2 -->
## 🔀 Delegation · chain `hf-20260913-a1b2`

| Repository | Task | Status | Updated | Result | Question |
| --- | --- | --- | --- | --- | --- |
| `owner/web` | [#17](…) | 🚀 DONE | 2026-09-13 11:20 | [result](…) | — |
| `owner/infra` | [#9](…) | ⛔ BLOCKED | 2026-09-13 11:40 | — | [question](…) |

<sub>⬜ NEW · 👀 WIP · ⛔ BLOCKED · 🚀 DONE · 👎 CANCELLED — each row is updated only by the agent of that repository</sub>
```

The row key is the slug in the first column between backticks. The parser works by that
key and leaves every other row untouched. The Question column is filled on blocking and
cleared by the assignee once the answer has been read.

## Result comment

```markdown
<!-- handoff:result v=1 repo=owner/api -->
### 📦 Result · `owner/api` · 2026-09-13 11:20

## What was done
## Contracts and integration points
## What the assignee must know
## What is still missing
```

Never edited. A new result is a new comment.

## Question comment: question and answer in one place

```markdown
<!-- handoff:question v=1 repo=owner/web -->
### ❓ Question · `owner/web` · 2026-09-13 11:40

## What is missing
## Options
## Done before blocking

---
### 💬 Answer · 2026-09-13 12:05

ISO-8601 in UTC.
```

The answer is appended to the same comment; no separate comment is created.
The responder adds a 👍 reaction to the comment.

| State | Meaning | What the assignee does |
|---|---|---|
| neither 👍 nor an Answer section | no answer yet | wait, do not resume |
| 👍 and an Answer section | answered | carry on, clear the Question column |
| 👍 without an Answer section | contradiction | stop, call a human (exit 7) |

## Dependent task

```markdown
**Context:** [result in owner/api#42](…#issuecomment-123) · **Status goes here:** [routing comment](…#issuecomment-124)

## Task
## Done when

<details><summary>🔗 handoff meta</summary>

```yaml
chain: hf-20260913-a1b2
key: 7f3c9a21
from: owner/api#42
context: https://github.com/owner/api/issues/42#issuecomment-123
routing: https://github.com/owner/api/issues/42#issuecomment-124
path: owner/api>owner/web
depth: 1
protocol: 1
plugin: 1.0.0
```
</details>
```

| Meta field | Purpose |
|---|---|
| `chain` | identifier of the delegation wave |
| `key` | idempotency: one task per "chain + repository" pair |
| `from` | the parent task |
| `context` | the result comment — the single source of context |
| `routing` | the routing comment — where the assignee writes status |
| `path` | the delegation route, cycle protection |
| `depth` | chain depth, checked against `HANDOFF_MAX_DEPTH` |
| `protocol` | the sender's major protocol version |
| `plugin` | the sender's plugin version, informational |

## Linking code

Code is linked to a task through the standard **Development** section: the pull request
body carries `Closes #<task number>`. Branch links never go into comments or the table.
`hf check` shows the linked PRs and flags closed tasks without one as `⚠no-PR`.

## Writing status and resolving conflicts

1. `GET` the comment → body and `updated_at` (the version).
2. Replace **only your own part**; everything else is carried over byte for byte.
3. `GET` again: the version moved → start over.
4. `PATCH`.
5. Verify with `GET`.
6. Still wrong — back off 1s/2s/4s with jitter, three attempts at most.

After three failures: exit code 75. Then the status on the task (the reaction) is
already set and is the source of truth, the task is marked BLOCKED, a human resolves
the conflict, and the table is restored with
`hf routing-render --ref <parent task>`.
