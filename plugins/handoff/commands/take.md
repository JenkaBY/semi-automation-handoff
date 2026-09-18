---
name: take
description: Pick up an incoming task — mark it in progress, pull the context from the requesting repository, plan the work with the developer and start only once the plan is approved.
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
3. **Write a plan and get it approved before changing anything.** Use
   `templates/work-plan.md`: the steps with the real files they touch, what is out of scope,
   how it will be verified, and the branch you propose (current, a new one off the
   development branch with a name you suggest, or one the developer names).
4. **Do not invent missing details.** Anything the task does not say is an open question:
   ask the developer here if it is about how to build it in this repository, or use
   `/handoff:block` if only the requester can answer what is actually wanted. A plan with
   open questions is not ready — resolve, revise, show it again.
5. Start only after the developer approves. If they changed anything, restate the plan as
   agreed first. Then do the work by THIS repository's rules, staying inside the plan.

**Do not push and do not open a pull request.** Commit locally and hand the developer the
commands; `gh pr create` pushes the branch, so it counts as pushing. Run either only when
they explicitly ask.

Exit code 5 means the protocol versions have drifted: do not start, tell the human.
When finished — `/handoff:report`: it publishes the result and closes the task.

If the task was blocked, always check the answer before resuming:
`hf question-status --ref <question url>`. Exit code 7 (👍 present, no answer) —
stop and ask the human.
