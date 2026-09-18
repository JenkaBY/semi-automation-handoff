# Template: work plan for an incoming task

Written after reading the task and its context, **before** any code changes, and shown to
the developer for approval. It stays in the session — do not post it to the issue, or the
requester's thread fills up with planning noise that is useful only locally.

Keep it to **20 lines at most**. A plan longer than the task is a sign you are designing
instead of planning.

```markdown
## Plan for <origin-repo>#<issue> — <task title>

**Branch:** <current | new `handoff/<origin-repo>-<issue>-<slug>` off `<base>` | name yours>

1. <step — what changes, in which file or module>
2. <step>
3. <step>

**Out of scope:** <what this deliberately does not touch>

**Verification:** <the command or check that proves it works>

**Open questions (blocking):**
- <question> — needs: <developer | requester>
```

## Rules that make the plan worth reviewing

- **Every step must trace to something you read** — the task prompt, the result comment, or
  this repository's code. If a detail is missing, it goes under "Open questions"; inventing a
  plausible answer is how a plan becomes wrong in a way nobody notices until review.
- **Name the real files.** "Update the API layer" cannot be reviewed; `src/api/orders.ts`
  can.
- **Say what you will not do.** Most disagreements at review time are about scope, not steps.
- **Address each question to the right person.** "How should this be built here?" is for the
  developer in front of you; "what exactly is needed?" belongs to the requester and goes
  through `/handoff:block`, which pauses the task properly.
