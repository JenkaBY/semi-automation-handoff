---
name: dispatch
description: Hand tasks to the agents of neighbouring repositories — commit the current changes, create or reuse a parent task, record the context and create tasks in the target repositories.
argument-hint: "[ref] <task description>"
disable-model-invocation: true
allowed-tools: Bash(hf *), Bash(bash *hf.sh *), Bash(gh *), Bash(git *), Read, Write
---

Hand work to the agents of neighbouring repositories. Do not change code yourself —
this is orchestration.

Input: $ARGUMENTS

If the input starts with a task reference (`42`, `#42`, `owner/repo#42` or a URL),
that is an existing parent task: use it and do not create a new one. The rest is the
task description.

Follow the `handoff-dispatch` skill (Skill: `handoff:handoff-dispatch`).

**Precondition first:** `git status --porcelain` must be empty. If anything is
uncommitted or untracked, stop and ask the developer what to do with it: commit or
revert. Decide only the commit format yourself — the one this repository uses, or,
if none is declared, meaningful groups with Conventional Commits messages.
Delegate only on top of committed changes.

After that the key rule: context is written once into the result comment, and task
prompts only link to it — they never re-tell it.

Finish by showing the parent task link, the routing comment link and the created tasks.
