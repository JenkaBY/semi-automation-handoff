---
name: take
description: Pick up an incoming task — mark it in progress, pull the context from the requesting repository and start the work on a dedicated branch.
argument-hint: "<ref>"
disable-model-invocation: true
allowed-tools: Bash(hf *), Bash(bash *hf.sh *), Bash(gh *), Bash(git *), Read, Write, Edit
---

Pick the task up and carry it out.

Task: $ARGUMENTS
No reference given — show `hf inbox` first and ask which one to take.

Follow the `handoff-inbox` skill (Skill: `handoff:handoff-inbox`):

1. `hf task-show --ref <ref> --context` — the prompt and the requester's context.
2. `hf status-set --ref <ref> --status WIP`.
3. Create a branch off the current development branch and do the work by THIS
   repository's rules, satisfying the "Done when" section.

Exit code 5 means the protocol versions have drifted: do not start, tell the human.
If a human decision is needed, do not guess: `/handoff:block`.
When finished — `/handoff:report`: it publishes the result and closes the task.

If the task was blocked, always check the answer before resuming:
`hf question-status --ref <question url>`. Exit code 7 (👍 present, no answer) —
stop and ask the human.
