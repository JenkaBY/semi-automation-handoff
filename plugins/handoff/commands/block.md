---
name: block
description: Pause an incoming task and ask a human — publish the question and mark the task blocked.
argument-hint: "[ref] <question>"
disable-model-invocation: true
allowed-tools: Bash(hf *), Bash(bash *hf.sh *), Bash(gh *), Read, Write
---

Stop working on the task and ask a question.

Input: $ARGUMENTS

Follow the `handoff-inbox` skill (Skill: `handoff:handoff-inbox`), section
"When a human decision is needed":

1. Write the question per `templates/question.md`: what is missing, which options exist
   and what they imply, what was done before blocking. One question, one block.
2. Publish and block:

```bash
hf comment-add --ref <ref> --body-file <file> --kind question
hf status-set --ref <ref> --status BLOCKED --question-url <url from step 1>
```

Do not continue after that. Tell the human exactly what you are waiting for and where
to see it. The answer will arrive in that same comment — check it with `hf question-status`.
