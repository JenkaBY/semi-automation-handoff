# Template: dependent task prompt

Body: **25 lines at most**. Re-telling the work already done is forbidden:
the "Context" link in the task header already points at it, added by `hf task-create`.

```markdown
## Task
<2–6 lines: what to do in THIS repository. Imperative, concrete.>

## Builds on
- The context link in the header — read it first (`/handoff:take` pulls it for you).

## Done when
- [ ] <checkable outcome>
- [ ] changes are opened as a pull request with `Closes #<this task number>` in its body

## Constraints
- <what must not change, backwards compatibility, deadlines>
```

Do not prescribe the implementation: the receiving repository has its own skills and
rules, and the agent there will decide better. State the outcome, not the method.
