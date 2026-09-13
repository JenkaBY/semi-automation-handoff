# The `hf` CLI

## How to call it

```bash
hf <subcommand> [arguments]
```

The plugin's `bin/` directory is on PATH, so `hf` is available directly.
If your shell cannot see it, use the fallback:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/hf.sh" <subcommand> [arguments]
```

It behaves the same on Windows (Git Bash), Linux and macOS. If `gh` is installed but
not on PATH, `hf` finds it in the usual install locations; a non-standard path goes
into the `HANDOFF_GH` variable.

## Task reference (REF)

Accepted in any form: `42` · `#42` · `owner/repo#42` ·
`https://github.com/owner/repo/issues/42` · `…/issues/42#issuecomment-123` ·
`-` (the session's current task). The first output line says what it resolved to.

## Subcommands

| Command | Purpose | Output |
|---|---|---|
| `doctor [--repo SLUG]` | preconditions: gh, token, permissions, labels, versions | `ok\|WARN\|FAIL` plus the item |
| `labels-ensure [--repo SLUG]` | create `agent-task` and `handoff:parent` | `ok<TAB>name` |
| `config-init [--repo SLUG] --peers "a b"` | `.handoff/config.env`, `.gitignore`, `.claude/settings.json` | `config<TAB>path<TAB>mode` |
| `peers-check [--repo SLUG] [--quiet]` | which neighbours' descriptions went stale (one GraphQL call per repo, no file contents) | `slug<TAB>new\|stale\|fresh\|unreachable<TAB>fingerprint<TAB>protocol<TAB>plugin` |
| `peers-stamp --repo SLUG [--fingerprint FP]` | mark a neighbour's description as up to date | `peers-stamp<TAB>slug<TAB>fingerprint<TAB>date` |
| `parent-ensure [--ref REF] --title T --body-file F` | create or mark the parent task | `parent<TAB>repo#N<TAB>url` |
| `comment-add --ref REF --body-file F [--kind result\|question\|note]` | add a comment | `comment<TAB>id<TAB>url` |
| `routing-ensure --ref REF [--chain C]` | find or create the routing comment | `routing<TAB>id<TAB>chain<TAB>url` |
| `task-create --target SLUG --title T --body-file F --routing URL --context URL [--path P] [--labels a,b]` | create a dependent task | `task<TAB>repo#N<TAB>url<TAB>created\|reused` |
| `task-show --ref REF [--context] [--no-body]` | task, status, PRs, context | metadata plus body |
| `inbox [--all] [--repo SLUG] [--limit N]` | incoming `agent-task` issues (one GraphQL call) | one line per task |
| `status-set --ref REF --status CODE [--result-url URL] [--question-url URL] [--clear-question] [--no-close]` | reaction plus the table row; DONE closes the task | `status<TAB>repo#N<TAB>CODE<TAB>routing:…` |
| `question-status --ref REF` | has the question been answered | `question<TAB>url<TAB>pending\|answered\|reacted-no-answer` |
| `answer --ref REF --body-file F` | append the answer to the question comment, 👍, lift the block | `answer<TAB>repo#N<TAB>url<TAB>…` |
| `check [--ref REF] [--render]` | summary of delegated tasks | `PARENT` / rows / `SUMMARY` |
| `accept --ref REF [--force]` | close the parent task once the chain is finished | `accept<TAB>repo#N<TAB>closed\|blocked\|pending` |
| `routing-render --ref REF` | rebuild the table from reactions | one line per repository |
| `version` | plugin and protocol versions | TSV |

## Exit codes

| Code | Meaning | What the agent does |
|---|---|---|
| 0 | success | carry on |
| 1 | `peers-check` only: something needs a refresh | re-survey the stale repositories |
| 2 | configuration/argument error, or a precondition is unmet | fix the call, never retry blindly |
| 3 | environment precondition failed (gh, auth, labels) | tell the human what to set up |
| 4 | cycle or depth exceeded | do not delegate; BLOCKED plus a question |
| 5 | protocol version mismatch | do not start work; report the version drift |
| 6 | entity not found | check the reference |
| 7 | question has 👍 but no answer | stop, call a human |
| 75 | conflict unresolved after 3 attempts | BLOCKED plus a human (see concurrency.md) |
