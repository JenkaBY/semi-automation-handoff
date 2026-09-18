# Template: question when blocked

Being blocked is not "I am stuck" — it is "a human decision is required".
One question, one block.

```markdown
## What is missing
<1–3 lines: which decision or data is absent>

## Options
1. <option> — consequences: <…>
2. <option> — consequences: <…>

## Done before blocking
- <briefly, so nobody restarts the work>
```

After posting: status BLOCKED (😕), the question link lands in the Question column
of the routing comment, work stops.

## How the answer arrives

The answer is appended **to the same comment** — there will be no separate comment,
so question and answer are always read together. The responder marks the comment with 👍.

Always run `hf question-status --ref <question link>` before resuming:

| Command says | What to do |
|---|---|
| `pending` | no answer yet — wait, do not resume |
| `answered` | the answer is printed too — carry on |
| `reacted-no-answer` | 👍 is there but no answer text — **stop and ask a human** |

Once you resume, clear the question link from your row: `hf status-set … --clear-question`.
