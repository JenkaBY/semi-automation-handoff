# Template: .handoff/external-repos.md

An agent reads this file before every delegation, so keep it short:
**12 lines per repository at most**.

```markdown
# External repositories

Updated: <date> · protocol: 1

## `owner/web`
- Purpose: <one line>
- Stack: <one line>
- Key directories: `src/…`, `…`
- Delegate here when: <signal>
- Do not delegate when: <signal>
- Useful labels: `frontend`, `ui`

## `owner/infra`
…
```

Do **not** record the plugin version here: it changes more often than the map and goes
stale immediately. If a neighbour has no plugin installed, or its protocol version
differs from the local one, warn the developer while building the map and warn again
in `hf doctor`. Tasks carrying a foreign major protocol version are never picked up (exit 5).

The repository list is duplicated in machine-readable form in `.handoff/config.env`
(`HANDOFF_PEERS`). The two must agree — `hf doctor` reports a mismatch.
