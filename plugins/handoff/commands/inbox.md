---
name: inbox
description: List tasks sent by agents of other repositories — issues labelled agent-task together with their reaction-based statuses.
argument-hint: "[--all]"
disable-model-invocation: true
allowed-tools: Bash(hf *), Bash(bash *hf.sh *), Bash(gh *)
---

List the incoming tasks for this repository.

```bash
hf inbox $ARGUMENTS
```

Show the list to the human as it comes: number, status, date, origin, title.
Status comes from the reaction on the task: 👀 WIP, 😕 BLOCKED, 🚀 DONE, 👎 CANCELLED,
no reactions means NEW; a closed task counts as finished.

Do not pick anything up without an explicit instruction — that is what `/handoff:take` is for.
If the list is empty, say so. On exit code 3, show what `hf doctor` reports.
