---
name: answer
description: Answer a blocked agent from another repository — the answer is appended to the same question comment and lifts the block.
argument-hint: "<ref> <answer>"
disable-model-invocation: true
allowed-tools: Bash(hf *), Bash(bash *hf.sh *), Bash(gh *), Read, Write
---

Answer the assignee and lift the block.

Input: $ARGUMENTS (a question comment reference or a task reference)

Follow the `handoff-status` skill (Skill: `handoff:handoff-status`), section
"Answering a blocked assignee":

1. Show the human the question text (`hf task-show --ref <ref>` or the comment itself)
   if they have not seen it yet.
2. If the answer is not in the arguments, or the question touches priorities, deadlines,
   compatibility or money, ask the human. Never make those decisions for them.
3. Write the answer to a file and run:

```bash
hf answer --ref <ref> --body-file <file>
```

The answer is appended to the same comment, 👍 appears on it and the task returns to NEW.
Never create a separate comment for an answer.
