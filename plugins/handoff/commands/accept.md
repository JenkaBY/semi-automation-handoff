---
name: accept
description: Close the parent task once the whole chain is finished — nothing blocked and every task in the neighbouring repositories closed by its assignee.
argument-hint: "<ref> [--force]"
disable-model-invocation: true
allowed-tools: Bash(hf *), Bash(bash *hf.sh *), Bash(gh *), Read
---

Close the delegation chain.

Input: $ARGUMENTS (a parent task reference; without it the session's current task)

Follow the `handoff-status` skill (Skill: `handoff:handoff-status`), section
"Closing the chain".

```bash
hf accept --ref <ref>
```

Do not review or second-guess anyone's work: a task closed by its assignee counts as
finished. The command refuses on its own if anything is blocked or unfinished — that is
a normal outcome: show the human what is left and suggest waiting.

Use `--force` only when the human explicitly asks to close despite unfinished work,
and always say what was left open.
