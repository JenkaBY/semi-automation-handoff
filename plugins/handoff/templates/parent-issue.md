# Template: parent task

Title: the gist in 5–9 words, no prefixes.
Body: **15 lines at most**. No code walkthroughs, no history.

```markdown
## Goal
<1–3 lines: what must be true once this is finished>

## Scope
- In: <…>
- Out: <…>

## Repositories involved
- `owner/web` — <why it is needed, one line>
- `owner/infra` — <…>
```

The `handoff:parent` label is added automatically.
If a human already filed the issue, use it (`/handoff:dispatch <ref> …`) — do not create a new one.
