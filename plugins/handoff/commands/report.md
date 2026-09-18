---
name: report
description: Report a finished incoming task — publish a short result, mark the task done and close it.
argument-hint: "[ref] [note]"
disable-model-invocation: true
allowed-tools: Bash(hf *), Bash(bash *hf.sh *), Bash(gh *), Bash(git *), Read, Write
---

Report the task you finished.

Input: $ARGUMENTS (the reference is optional — without it the session's current task is used)

Follow the `handoff-inbox` skill (Skill: `handoff:handoff-inbox`), section "Report":

1. Check what is still local: `git status --porcelain` and `git log --oneline @{u}..`.
   If commits are unpushed, say so and ask the developer whether to report now or wait for
   the push. **Do not push and do not open the pull request yourself** — hand them the
   commands (`git push -u origin <branch>`, then `gh pr create --fill --body "Closes #<n>"`)
   and run them only if they ask in as many words.
2. Write the result per `templates/result-comment.md`, 40 lines at most: what was done,
   contracts and integration points, what is still missing. Write it for a foreign agent
   that has never seen your code. No branch links.
3. Publish and close:

```bash
hf comment-add --ref <ref> --body-file <file> --kind result
hf status-set --ref <ref> --status DONE --result-url <url from the previous command>
```

`--status DONE` closes the task: a finished task is a closed task. Closing it before the
pull request exists is allowed — the requester's summary will flag `⚠no-PR`, which is an
honest signal — but let the developer decide rather than deciding for them.
