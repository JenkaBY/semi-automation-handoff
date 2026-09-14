---
name: handoff-release
description: Cut a release of the handoff plugin — bump the version, update the pinned install tag everywhere, write the changelog entry and tag the commit. Use whenever someone says "release", "cut a version", "bump the version", "prepare vX.Y.Z", or asks why repositories ended up on different plugin versions. The version lives in two manifests and five documents that must agree; a partial bump is the usual cause of a fleet where doctor reports a mismatch.
---

# Releasing the handoff plugin

The plugin must be installed at the **same version in every participating repository** —
that is a property of the protocol, not a preference. A release that updates the manifest
but not the pinned tag in the docs makes people install an older plugin while believing
they are current, so treat the sweep below as one atomic change.

## 1. The tree must be green and clean

```bash
bash plugins/handoff/tests/run.sh
for f in $(find plugins -name '*.sh') plugins/handoff/bin/hf plugins/handoff/tests/mock/gh; do bash -n "$f" || echo "SYNTAX $f"; done
git status --porcelain
```

## 2. Decide which number moves

Two independent numbers, and confusing them is expensive:

| Number | Where | Bump when |
|---|---|---|
| **Plugin version** | `plugins/handoff/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` | any user-visible change; semver as usual |
| **Protocol** (`HANDOFF_PROTOCOL`, `metadata.protocolVersion`) | manifest metadata, `.handoff/config.env` of every repository | only when issue bodies, the routing table or the comment markers change shape |

A protocol bump makes every repository on the old major refuse incoming tasks with exit 5.
That is intended — but it means the fleet must be upgraded together, so say so loudly in the
changelog and warn the user before doing it.

## 3. The sweep

Confirm the current occurrences instead of trusting this list — files move:

```bash
grep -rn '"version"' .claude-plugin/marketplace.json plugins/handoff/.claude-plugin/plugin.json
grep -rn 'semi-automation-handoff@v' --include='*.md' . | grep -v '\.git/'
grep -rn '^plugin: ' docs/en/protocol.md docs/ru/protocol.md
```

At the time of writing that is: two manifests, the install command in `README.md`,
`docs/en/setup.md`, `docs/ru/setup.md`, `docs/en/troubleshooting.md`,
`docs/ru/troubleshooting.md`, and the sample `plugin:` line in both `protocol.md` files.

## 4. Changelog

Add a section to `CHANGELOG.md` in Keep a Changelog form, newest first. Write what changed
for a *user of the plugin* and why, not a list of commits. If the protocol moved, state
plainly that repositories must be upgraded together; if it did not, state that old and new
versions still understand each other — that is the question people actually have.

## 5. Commit and tag

```bash
git commit -m "chore(release): bump to X.Y.Z"      # plus the Co-Authored-By trailer
git tag vX.Y.Z
```

The tag is what `/plugin marketplace add owner/repo@vX.Y.Z` resolves, so an untagged release
is invisible to anyone installing by tag.

**Pushing is the user's call.** Do not push the branch or the tag unless they ask — and say
explicitly that until the tag is pushed, the documented install command will not work.

## 6. After the release

Remind the user to run `/plugin marketplace update handoff-marketplace` in each repository
and to check `hf version` there. `hf doctor` will not catch a version drift on its own; the
drift surfaces later as exit 5 on a task nobody can pick up.
