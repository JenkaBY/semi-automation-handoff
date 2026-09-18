---
name: handoff-inbox
description: Take on tasks sent by agents of other GitHub repositories — list incoming agent-task issues, pick one up, plan the work and get the plan approved, then do it and report the result or a blocking question. Use when you need to look at or start work on a task filed by another repository. Pushing and opening pull requests stay the developer's call.
argument-hint: "[ref]"
---

# Taking on incoming tasks

Protocol: `${CLAUDE_PLUGIN_ROOT}/skills/handoff-protocol/SKILL.md`.
Templates: `${CLAUDE_PLUGIN_ROOT}/templates/work-plan.md`, `result-comment.md`, `question.md`.

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

## 3. Plan first — and do not start until the plan is approved

Read the prompt and the context, then write a plan per
`${CLAUDE_PLUGIN_ROOT}/templates/work-plan.md` (≤20 lines) and give it to the developer for
review. **No code changes until they approve it.** The task came from another repository and
its author is not in the room: a plan is the cheapest moment to discover that you understood
the request differently from the person who wrote it.

The plan states the steps with the real files they touch, what is deliberately out of scope,
how the result will be verified, and the branch you propose:

1. **the current branch** — when it is already the working branch for this task;
2. **a new branch off the current development branch** — propose a name derived from the
   task, e.g. `handoff/<origin-repo>-<issue>-<slug>`;
3. **an existing branch** they name.

Asking about branch and plan together costs the developer one reply instead of two. Do not
create or switch branches on your own: which branch the work lands on decides what gets
reviewed and released, and only the developer knows what else is in flight here. Working
directly on the main branch needs them to say so explicitly.

### Never fill a gap by guessing

If the task does not say something you need, that is an open question, not an invitation to
decide. Route it to whoever can actually answer:

| Missing | Ask | How |
|---|---|---|
| how something should be built *here* — conventions, which module owns this, which branch | the developer in front of you | in the session, as part of the plan review |
| what the requester actually wants — scope, format, acceptance | the requester's repository | `/handoff:block`, which pauses the task and records the question |

A plan with open questions is not ready to execute. Resolve them, revise the plan, show it
again. If the developer is unavailable and the questions are theirs, park the task with
BLOCKED rather than starting on assumptions — a wrong branch is cheap to delete, a day of
work aimed at the wrong target is not.

When the developer changes the plan, restate it as agreed before you start, so that what was
approved and what you are about to do are provably the same thing.

## 4. Do the work

The work follows THIS repository's rules — that is exactly why the task came here.

- Commit in the format used here (`git log --oneline -20`, `CONTRIBUTING*`);
  if none is declared, use Conventional Commits, one commit per meaningful group.
- Satisfy the "Done when" section of the prompt, and stay inside the approved plan — if the
  work turns out to need a step nobody approved, stop and get the change agreed first.

## 5. Hand the changes over — do not push

Commit locally, then stop. **Never push and never open a pull request on your own.** The
developer decides when work leaves the machine, and `gh pr create` pushes the branch as a
side effect, so it counts as pushing.

Say the work is ready and hand them the exact commands:

```bash
git push -u origin <branch>
gh pr create --fill --body "Closes #<task number>"
```

Keep `Closes #<number>` in the suggestion: that keyword is what links the changes to the
task through the standard **Development** section. Run either command yourself only when the
developer says so in as many words — "push it", "open the PR". Never paste branch links into
comments or the routing table; the Development section is where that link belongs.

## 6. Report

First see what is still local:

```bash
git status --porcelain
git log --oneline @{u}.. 2>/dev/null
```

If commits are unpushed, tell the developer and ask whether to report now or wait for the
push. Reporting now is legitimate — the requester's summary will simply flag the task as
`⚠no-PR`, which is honest rather than broken — but it should be their choice.

Result per `templates/result-comment.md` (≤40 lines: what was done, contracts, what is missing).

```bash
hf comment-add --ref <ref> --body-file <file> --kind result
hf status-set --ref <ref> --status DONE --result-url <url from the previous command>
```

`status-set --status DONE` **closes the task**: a finished task is a closed task.

## 7. When a human decision is needed

One question, one block. Text per `templates/question.md`.

```bash
hf comment-add --ref <ref> --body-file <file> --kind question
hf status-set --ref <ref> --status BLOCKED --question-url <question url>
```

Stop working and tell the human what you are waiting for.

## 8. Resuming a blocked task

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
