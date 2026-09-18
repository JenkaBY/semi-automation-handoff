# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versions follow [Semantic Versioning](https://semver.org/).

## [1.0.0] — 2026-09-18

First stable release. The command surface and the wire protocol are now considered
settled: from here on, a breaking change to either gets a major bump.

**Protocol stays at version 1**, so this is not a fleet-wide upgrade — repositories on
0.3.0 and 1.0.0 still understand each other's tasks. Upgrade them when convenient; what
changes here is how the assignee agent behaves locally, not what it writes into GitHub.

### Changed

- **`/handoff:take` plans before it works.** It writes a plan — steps with the real
  files, what is out of scope, how it will be verified, the branch it proposes — and
  waits for the developer to approve it before changing anything. The task comes from
  another repository whose author is not in the room, so the plan is the cheapest
  moment to find out the request was understood differently than it was meant.
- **Missing details are never invented.** What the task does not say becomes an open
  question routed to whoever can answer it: the developer in the session for "how do we
  build this here", `/handoff:block` for "what does the requester actually want". A plan
  with open questions is not executed.
- **The branch is agreed, not chosen by the agent:** the current branch, a new one off
  the development branch (it proposes a name), or one the developer names. Which branch
  the work lands on decides what gets reviewed and released, and only the developer
  knows what else is in flight.
- **The agent no longer pushes or opens pull requests.** It commits locally and hands
  over the commands; `gh pr create` pushes the branch as a side effect, so it counts
  as pushing. Both wait for an explicit instruction, because a push is immediately
  visible to everyone else.
- `/handoff:report` reports what is still unpushed and asks whether to report now or
  wait. Closing a task before its pull request exists stays allowed — the requester
  sees `⚠no-PR`, which is honest — but it is the developer's call.

### Added

- `templates/work-plan.md` — the plan format the assignee fills in: 20 lines, real
  file names, explicit out-of-scope, and blocking open questions addressed to either
  the developer or the requester.

## [0.3.0] — 2026-09-13

### Added

- **`/handoff:refresh`** — keep the map of neighbouring repositories current.
  Repositories evolve, and a stale `.handoff/external-repos.md` sends work to the
  wrong place.
- `hf peers-check` finds out what actually changed before anything is re-surveyed:
  one GraphQL request per repository fetches only the blob ids of `README.md`,
  `AGENTS.md`, `CLAUDE.md` and `.handoff/config.env` — never their contents — and
  compares them with the new `.handoff/peers.lock`. Subagents are spent only on
  repositories marked `stale` or `new`. It exits 1 when a refresh is due, and also
  reports neighbours with no plugin installed or a drifted protocol version.
- `hf peers-stamp` records a repository as surveyed, after its section is rewritten.
- `hf doctor` reports the age of the map from the lock file with no network call and
  warns past `HANDOFF_MAP_MAX_AGE_DAYS` (30 by default), so the reminder to refresh
  arrives on its own.

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
