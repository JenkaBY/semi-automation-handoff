# Template: result comment (context for other agents)

This is the **only** carrier of context for assignees: a task prompt links to it
and never re-tells it. The comment is append-only — never edit it; a new result
becomes a new comment.

Body: **40 lines at most**. Write what a foreign agent needs in order to start.

```markdown
## What was done
- <a fact, not an intention>

## Contracts and integration points
| What | Where | Shape |
| --- | --- | --- |
| `POST /v2/orders` | `owner/api` | request schema: … |

## What the assignee must know
- <constraint, agreement, sharp edge>

## What is still missing
- <state it explicitly so nobody goes looking>
```

Do **not** paste branch or commit links here: code is linked to the task through the
standard Development section — write `Closes #<task number>` in the pull request body.
GitHub then shows the PR on the issue, and `hf check` shows it in the summary.

The heading and the service marker are added by `hf comment-add --kind result`.
