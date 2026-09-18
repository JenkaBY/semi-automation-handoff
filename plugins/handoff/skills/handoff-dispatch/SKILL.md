---
name: handoff-dispatch
description: Hand tasks to the agents of neighbouring GitHub repositories — commit the current changes, create the parent task, the result comment carrying context, the routing comment with statuses, and the dependent tasks. Use when part of the work belongs in another repository.
argument-hint: "[ref] <task description>"
---

# Handing tasks to neighbouring repositories

Protocol: `${CLAUDE_PLUGIN_ROOT}/skills/handoff-protocol/SKILL.md`.
Templates: `${CLAUDE_PLUGIN_ROOT}/templates/`.

**Dispatch changes no code itself.** It is pure orchestration on top of changes that
have already been committed.

## 0. Precondition: the working tree is committed

```bash
git status --porcelain
git branch --show-current
```

Empty output — carry on. Anything uncommitted (untracked files included) —
**stop and ask the developer** what to do with it: commit or revert.
Do not decide for them and never commit silently.

If they choose to commit:

1. Look at how this repository does it: `git log --oneline -20`, `CONTRIBUTING*`,
   a commitlint or husky config. If there is a house format, follow it.
2. If no format is declared, group the changes by meaning and commit **each group
   separately**, with [Conventional Commits](https://www.conventionalcommits.org/) messages:
   `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`.
3. Work happens on a development branch, not on the main one. If you are on the main
   branch, ask the developer which branch to move to.

Only once the tree is clean, move on to delegation.

## 1. The map of neighbours

Read `.handoff/external-repos.md`. Missing — tell the human to run `/handoff:init`
and stop there. Decide which repositories genuinely need a task: one repository,
one task per chain.

## 2. Parent task

If the human gave a reference (`42`, `owner/repo#42`, a URL), use it — do not create a new one:

```bash
hf parent-ensure --ref <ref>
```

Otherwise write the body from `templates/parent-issue.md` (≤15 lines):

```bash
hf parent-ensure --title "<the gist in 5–9 words>" --body-file <file>
```

## 3. Result comment — context for foreign agents

The only place assignees take context from. Fill it in per `templates/result-comment.md`
(≤40 lines): facts, contracts, constraints, what is still missing. No branch links —
code is linked through Development (`Closes #<number>` in the PR body).

```bash
hf comment-add --ref <parent task> --body-file <file> --kind result
```

The URL it prints goes into `--context`.

## 4. Routing comment

```bash
hf routing-ensure --ref <parent task>
```

## 5. Dependent tasks

Prompt per `templates/task-body.md` (≤25 lines). **Do not re-tell the work already done.**

```bash
hf task-create --target owner/web --title "<the gist>" --body-file <file> \
  --routing <routing-comment-url> --context <result-comment-url> [--labels frontend]
```

The command checks cycle and depth, adds the `agent-task` label, embeds the metadata
and protocol version, leaves the routing link as the first comment and fills in the
table row. `created` — a new task; `reused` — it already existed in this chain and was updated.

## 6. Report to the human

The parent task link, the routing comment link, one line per target repository.
Remind them that statuses live in `/handoff:check`.

## Error codes

| Code | What to do |
|---|---|
| 2 | the repository is not in `HANDOFF_PEERS` — run `/handoff:init` first |
| 4 | cycle or depth exceeded — do not delegate, explain to the human |
| 3 | no `gh`, no auth or no labels — show the `hf doctor` output |
| 75 | task created but the table was not updated — suggest `hf routing-render --ref <parent>` |
