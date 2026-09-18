---
name: init
description: Prepare this repository for cross-repository task handoff — check gh and permissions, create the labels, collect a map of neighbouring repositories and write the configuration.
argument-hint: "[owner/repo ...]"
disable-model-invocation: true
allowed-tools: Bash(hf *), Bash(bash *hf.sh *), Bash(gh *), Read, Write, Edit, Agent
---

Prepare the current repository for the handoff plugin.

Neighbouring repositories: $ARGUMENTS
If the list is empty, ask the human which repositories need to talk to each other.

Follow the `handoff-setup` skill exactly (Skill: `handoff:handoff-setup`).
Create nothing in other people's repositories: this step only reads and writes local files.
Subagents read `README.md`, `AGENTS.md`, `CLAUDE.md` and `.handoff/config.env` of each
neighbour and **do not follow links** found in those files.

Always warn the developer if a neighbour has no plugin installed or its protocol version
differs from the local one — that repository's agent will not be able to pick tasks up.

Finish by showing the `hf doctor` result and the list of files worth committing.
