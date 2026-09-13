---
name: report
description: Report a finished incoming task — publish a short result, mark the task done and close it.
argument-hint: "[ref] [note]"
disable-model-invocation: true
allowed-tools: Bash(hf *), Bash(bash *hf.sh *), Bash(gh *), Read, Write
---

Report the task you finished.

Input: $ARGUMENTS (the reference is optional — without it the session's current task is used)

Follow the `handoff-inbox` skill (Skill: `handoff:handoff-inbox`), sections
"Open a pull request" and "Report":

1. If code changed, make sure it is opened as a pull request whose body contains
   `Closes #<task number>` — that is how the PR lands in the task's Development section.
2. Write the result per `templates/result-comment.md`, 40 lines at most: what was done,
   contracts and integration points, what is still missing. Write it for a foreign agent
   that has never seen your code. No branch links.
3. Publish and close:

```bash
hf comment-add --ref <ref> --body-file <file> --kind result
hf status-set --ref <ref> --status DONE --result-url <url from the previous command>
```

`--status DONE` closes the task: a finished task is a closed task.
