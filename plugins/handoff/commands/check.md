---
name: check
description: Show the status of tasks handed to other repositories — a summary from the routing comment with flags for stale, stalled and blocked tasks.
argument-hint: "[ref] [--render]"
disable-model-invocation: true
allowed-tools: Bash(hf *), Bash(bash *hf.sh *), Bash(gh *)
---

Show how the delegated tasks are progressing.

Input: $ARGUMENTS (no reference — every open parent task in this repository)

```bash
hf check $ARGUMENTS
```

Follow the `handoff-status` skill (Skill: `handoff:handoff-status`), section "Summary":
read the flags at the end of each line and tell the human what to do next:

- `⟲stale-table` — suggest `hf check --ref <ref> --render`;
- `⏳stalled` — just report it, take no action yourself;
- `⚠no-PR` — the task is closed with no pull request linked, ask whether code changed;
- status BLOCKED — show the question and suggest `/handoff:answer`;
- everything finished — suggest `/handoff:accept` to close the parent task.
