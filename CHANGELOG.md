# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versions follow [Semantic Versioning](https://semver.org/).

## [0.2.0] — 2026-09-13

Protocol revision after review, plus a full English translation of the plugin and its
documentation (the Russian documentation stays in `docs/ru/`). The protocol version
remains 1: the plugin had not been deployed, so there is no compatibility to break.

### Changed

- **Status is carried by reactions only** (👀 WIP, 😕 BLOCKED, 🚀 DONE, 👎 CANCELLED,
  no reactions — NEW). The seven status labels are gone; two non-status labels remain,
  `agent-task` and `handoff:parent`, kept only where `gh` can filter.
- **ACCEPTED and REWORK removed.** There is no acceptance step: the orchestrator does
  not judge code quality. A finished task is a closed task, closed by the assignee in
  `/handoff:report`.
- **`/handoff:accept` now operates on the parent task**: it closes it once nothing is
  blocked and every dependent task is finished, and refuses with a list otherwise.
- **A question and its answer live in one comment.** `/handoff:answer` appends the
  answer to the question comment and marks it 👍. No separate answer comment is created.
- **`/handoff:dispatch` requires a committed tree.** With uncommitted or untracked
  files the agent stops and asks the developer; commits follow the repository's format,
  otherwise meaningful groups with Conventional Commits.
- Code is linked to tasks through the standard **Development** section
  (`Closes #N` in the PR body); branch links no longer appear in comments or the table.
- Token permissions: Contents and Pull requests — Read & Write added (branches, push, PRs).
- `/handoff:init` also reads neighbours' `AGENTS.md` and `CLAUDE.md` and does not follow
  links out of them; plugin versions are no longer recorded in `external-repos.md`,
  replaced by a drift warning.

### Added

- A Question column in the routing comment: the assignee fills it when blocking and
  clears it once the answer has been read.
- `hf question-status` — check a question before resuming; the "👍 present, answer
  missing" contradiction exits with code 7 and stops the work.
- `hf inbox` fetches the list, states and reactions in a single GraphQL request.
- `hf_issue_facts` — status, dates and linked PRs in one request; the summary gained
  a `⚠no-PR` flag.
- Explicit Windows, Linux and macOS support: GNU/BSD fallbacks for `date`, `gh`
  discovery outside PATH in all three systems' install locations.
- Adding the marketplace from a local directory, for plugin development.

### Fixed

- Consecutive empty TSV fields collapsed on read (tab is IFS whitespace), which shifted
  columns: a closed task showed up as NEW and its title was lost. Placeholders are now
  emitted on both sides, with regression tests.

## [0.1.0] — 2026-09-12

First release: commands, skills, the `hf` CLI, the status model, optimistic locking,
cycle protection and offline tests.
