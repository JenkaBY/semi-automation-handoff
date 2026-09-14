---
name: handoff-i18n
description: Keep this repository's bilingual documentation and its user-facing strings in sync. Use whenever a change touches docs/en or docs/ru, edits a string the plugin writes into GitHub (table headers, comment headings, summary flags), adds a command or subcommand that needs documenting, or when someone says "translate", "the docs are out of date", "this is still in Russian". A naive grep for Cyrillic silently finds nothing in the C locale, so untranslated text hides easily — use the byte-level search below.
---

# Bilingual documentation and strings

English is the working language of the code, the skills and the templates. `docs/ru/` is a
mirror of `docs/en/`, kept for the repository owner. The pairs are
`architecture.md`, `protocol.md`, `setup.md`, `troubleshooting.md`, `usage.md`, plus
`README.md` which links to both trees.

## Finding untranslated text

`grep -P '[А-Яа-я]'` matches **nothing** in the C locale because it compares byte by byte —
it will happily report a clean tree while Russian text sits in the manifests. Cyrillic in
UTF-8 always starts with `0xD0` or `0xD1`, so search for those:

```bash
LC_ALL=C grep -rn $'[\xd0\xd1]' --exclude-dir=.git --exclude-dir=ru --exclude='*.zip' .
```

Everything it reports should be one of the deliberate `*Русская версия: …*` links at the top
of each English document. Anything else is a miss.

## What must change together

A string the plugin writes into a GitHub issue is not just code — it is documented protocol.
Changing one without the others makes the documentation lie about what users will see:

| Change | Also update |
|---|---|
| routing table header (`lib/table.sh`) | `docs/*/protocol.md` sample table |
| comment heading (`📦 Result`, `❓ Question`, `### 💬 Answer`) | `docs/*/protocol.md`, and every `grep`/`jq` filter matching it — `cmd/answer.sh`, `cmd/question-status.sh`, `tests/mock/gh` |
| summary flags (`⟲stale-table`, `⏳stalled`, `⚠no-PR`, `⚠no-access`) | `docs/*/troubleshooting.md`, `skills/handoff-status/SKILL.md`, `commands/check.md` |
| a new subcommand | `skills/handoff-protocol/references/cli.md`, both `setup.md`/`usage.md` where relevant |
| a new config key | both `setup.md` tables, `cmd/config-init.sh`, `lib/config.sh` defaults |

## Order of work

Write English first — it is the source and the language the code speaks — then mirror into
Russian. Translate meaning, not words: the Russian text explains the same behaviour to the
same reader, and both documents keep the same headings and structure so a diff between them
stays reviewable.

Examples inside the Russian documents show the **literal strings the plugin emits**, which
are English. Do not translate the contents of a sample table, comment or command output;
translate only the prose around them. Otherwise the documentation describes a plugin that
does not exist.

## Verify

```bash
LC_ALL=C grep -rn $'[\xd0\xd1]' --exclude-dir=.git --exclude-dir=ru --exclude='*.zip' .
ls docs/en docs/ru          # the same five files on both sides
grep -c '' docs/en/protocol.md docs/ru/protocol.md   # wildly different lengths mean drift
```
