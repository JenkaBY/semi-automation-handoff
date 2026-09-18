---
name: refresh
description: Refresh the descriptions of neighbouring repositories in .handoff/external-repos.md — re-survey only the repositories whose sources actually changed since the last refresh.
argument-hint: "[owner/repo ...] [--check]"
disable-model-invocation: true
allowed-tools: Bash(hf *), Bash(bash *hf.sh *), Bash(gh *), Read, Write, Edit, Agent
---

Bring the map of neighbouring repositories up to date.

Repositories: $ARGUMENTS (empty — every repository in `HANDOFF_PEERS`)

Follow the `handoff-setup` skill (Skill: `handoff:handoff-setup`), section
"Refreshing the map later".

1. `hf peers-check` — find out what actually changed. It compares blob ids of
   `README.md`, `AGENTS.md`, `CLAUDE.md` and `.handoff/config.env` against
   `.handoff/peers.lock` and never downloads their contents.
2. If the arguments contain `--check`, stop here and report what is stale.
3. Re-survey **only** the `stale` and `new` repositories with subagents (at most three
   in parallel, read-only, no following links out of those files).
4. Rewrite only those repositories' sections in `.handoff/external-repos.md`, leaving
   everything else untouched, and update the "Updated" date.
5. `hf peers-stamp --repo <slug> --fingerprint <from peers-check>` for each repository
   whose section you rewrote — after writing it, never before.

Report to the human: what was fresh and skipped, what was re-surveyed and what changed
in it. Pass on any warning about a missing plugin or a protocol version mismatch.
