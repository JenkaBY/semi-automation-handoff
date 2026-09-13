---
name: handoff-inbox
description: Take on tasks sent by agents of other GitHub repositories — list incoming agent-task issues, pick one up, do the work, open a pull request and report the result or a blocking question. Use when you need to look at or start work on a task filed by another repository.
argument-hint: "[ref]"
---

# Taking on incoming tasks

Protocol: `${CLAUDE_PLUGIN_ROOT}/skills/handoff-protocol/SKILL.md`.
Templates: `${CLAUDE_PLUGIN_ROOT}/templates/result-comment.md`, `question.md`.

## 1. See what came in

```bash
hf inbox
```

One line per task: number, status, date, where it came from, title. Show the list to
the human and ask which one to take if they did not say.

## 2. Pick it up

```bash
hf task-show --ref <ref> --context
hf status-set --ref <ref> --status WIP
```

`task-show --context` returns both the prompt and the requester's result comment —
that is all the context you need. `status-set` adds the 👀 reaction and updates your
row in the requester's routing comment.

**Exit code 5** — the task was created by a plugin with a different major protocol
version. Do not start: tell the human the plugin versions have drifted apart.

## 3. Do the work

The work follows THIS repository's rules — that is exactly why the task came here.

- Create a branch off the current development branch.
- Commit in the format used here (`git log --oneline -20`, `CONTRIBUTING*`);
  if none is declared, use Conventional Commits, one commit per meaningful group.
- Satisfy the "Done when" section of the prompt.

## 4. Open a pull request

```bash
gh pr create --fill --body "Closes #<task number>"
```

`Closes #<number>` is required: it is what links the changes to the task through the
standard **Development** section. Never paste branch links into comments or the table.

## 5. Report

Result per `templates/result-comment.md` (≤40 lines: what was done, contracts, what is missing).

```bash
hf comment-add --ref <ref> --body-file <file> --kind result
hf status-set --ref <ref> --status DONE --result-url <url from the previous command>
```

`status-set --status DONE` **closes the task**: a finished task is a closed task.

## 6. When a human decision is needed

One question, one block. Text per `templates/question.md`.

```bash
hf comment-add --ref <ref> --body-file <file> --kind question
hf status-set --ref <ref> --status BLOCKED --question-url <question url>
```

Stop working and tell the human what you are waiting for.

## 7. Resuming a blocked task

```bash
hf question-status --ref <question url>
```

| Result | What to do |
|---|---|
| `pending` | no answer yet — do not resume |
| `answered` | the answer is printed right there — carry on |
| `reacted-no-answer` (exit 7) | 👍 is there but no answer text — **stop and ask a human** |

Once you resume, clear the question link from your row:

```bash
hf status-set --ref <ref> --status WIP --clear-question
```

## If a third repository turns out to be needed

You may delegate onwards — use the `handoff-dispatch` skill within the same chain.
Exit code 4 means it would create a cycle: do not work around the guard, file a
BLOCKED question instead.

## Errors

Exit code 75 — the status on the task (the reaction) is set, but the row in the
requester's table was not updated. Tell the human and suggest they run
`hf routing-render --ref <parent task>`.
