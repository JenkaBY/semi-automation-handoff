---
name: gh-mock
description: Extend or debug the offline gh mock that backs this repository's test suite. Use whenever a test fails with an empty or unexpected value from gh, a new subcommand calls a GitHub endpoint the tests have never exercised, or someone says "the mock doesn't know about this", "why does the test pass but the real thing break". The mock emulates gh after --jq, not raw JSON — writing it as if it returned API responses is the usual mistake.
---

# The `gh` mock

`plugins/handoff/tests/mock/gh` is a small file-backed model of GitHub. The suite puts it
first in `PATH`, so every call from `lib/gh.sh` lands here and the tests run with no network.
That only holds while all network access goes through `lib/gh.sh` — a raw `gh` call inside a
`cmd/` script bypasses the mock and quietly stops being tested.

## The one thing to get right

The mock emulates `gh` **after** its `--jq` filter has run. It prints what the real pipeline
would print — usually a TSV line or a bare value — not JSON for the plugin to parse.

So it branches on the *shape of the jq expression it was handed*, not on the endpoint alone:

```bash
case "$jq" in
  *closedByPullRequestsReferences*) printf '%s\t%s\t%s\t%s\n' "$state" "$reactions" "$date" "$prs" ;;
  *.state*)  printf '%s\n' "$state" ;;
  *labels*)  printf '%s\n' "$lab" ;;
esac
```

When you add a call with a new `--jq`, add a matching branch. Match on something distinctive
in the expression; a too-generic pattern will swallow another command's call.

## State on disk

Everything lives under `$HF_MOCK_DIR`:

| Path | Holds |
|---|---|
| `issues/<owner_repo>/<n>.{body,title,labels,state,reactions}` | one issue; its reactions are `<id> <content>` lines, because the plugin deletes its own reactions by id |
| `comments/<id>.{body,ts,reactions}` | one comment; `ts` is the version `updated_at` compares, and comment reactions are bare `<content>` lines since nothing deletes them |
| `comment_index` | `<comment id> <owner/repo>#<issue>` |
| `peers/<owner_repo>.{src,proto}` | sources fingerprint and protocol for `peers-check` |

## Simulating a concurrent writer

The optimistic-locking tests depend on somebody else editing the comment mid-flight:

- `HF_MOCK_INTERFERE=<n>` — another agent appends a row after the n-th read of `updated_at`
- `HF_MOCK_INTERFERE_ALWAYS=1` — on every read, which drives the retry budget to exhaustion
  and must produce exit 75

Pair these with `HF_NO_SLEEP=1` so the backoff does not make the suite crawl.

## Adding an endpoint

1. Find where the real call is made in `lib/gh.sh` or a `cmd/` script and note the exact
   `--jq` it passes.
2. Add a `case` branch keyed on the path, then on that `--jq` shape.
3. Print exactly what the real command prints — including a placeholder for any field that
   can be empty. Empty TSV fields collapse on `read` and shift every later column; the mock
   emits `-` for those and the caller converts back.
4. Add the test that needs it to `tests/run.sh`, and run the whole suite — mock branches are
   easy to make too greedy, and the failure shows up in an unrelated test.

## When the mock disagrees with reality

The mock proves the plugin's logic, not GitHub's API contract. If a command behaves
correctly offline but not against a real repository, trust the real repository and fix the
mock to match it — then keep the test that would have caught it.
