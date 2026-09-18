#!/usr/bin/env bash
# lib/table.sh — the routing comment's status table.
#
# Row format (the key is the slug in the first column, between backticks):
#   | `owner/web` | [#17](url) | 👀 WIP | 2026-09-12 11:20 | [result](url) | [question](url) |
#
# Ownership rule: a repository's row is only ever edited by that repository's agent.
# Every other row is carried over byte for byte, so concurrent edits are not lost.
# The Question column stays filled until the assignee has read the answer and clears it.

HF_ROUTING_MARKER_PREFIX='<!-- handoff:routing v=1 chain='
HF_TABLE_HEADER='| Repository | Task | Status | Updated | Result | Question |'
HF_TABLE_SEP='| --- | --- | --- | --- | --- | --- |'

hf_now_utc() { date -u '+%Y-%m-%d %H:%M'; }

# Portable ISO-8601 → epoch: GNU date first, then BSD/macOS date.
hf_date_epoch() {
  local iso="$1" out plain
  out=$(date -u -d "$iso" +%s 2>/dev/null) && [ -n "$out" ] && { printf '%s' "$out"; return 0; }
  plain=${iso%%.*}; plain=${plain%Z}
  out=$(date -u -j -f '%Y-%m-%dT%H:%M:%S' "$plain" +%s 2>/dev/null) && [ -n "$out" ] && { printf '%s' "$out"; return 0; }
  return 1
}

# hf_table_body_new <chain> — skeleton of the routing comment
hf_table_body_new() {
  local chain="$1"
  printf '%s%s -->\n' "$HF_ROUTING_MARKER_PREFIX" "$chain"
  printf '## 🔀 Delegation · chain `%s`\n\n' "$chain"
  printf '%s\n%s\n\n' "$HF_TABLE_HEADER" "$HF_TABLE_SEP"
  printf '<sub>%s — each row is updated only by the agent of that repository</sub>\n' "$(hf_status_legend)"
}

hf_table_chain() {
  sed -n 's/^<!-- handoff:routing v=1 chain=\([^ ]*\) -->.*/\1/p' "$1" | head -1
}

# hf_table_rows <file> — TSV: slug, task(md), status, updated, result(md), question(md)
hf_table_rows() {
  awk '
    substr($0,1,3) == "| `" {
      line = $0
      sub(/^\| /, "", line); sub(/ \|[[:space:]]*$/, "", line)
      n = split(line, c, / \| /)
      slug = c[1]; gsub(/`/, "", slug)
      # Never emit empty fields: tab is IFS whitespace, so consecutive separators
      # would collapse and shift the columns for whoever reads this.
      for (i = 2; i <= 6; i++) if (i > n || c[i] == "") c[i] = "—"
      printf "%s\t%s\t%s\t%s\t%s\t%s\n", slug, c[2], c[3], c[4], c[5], c[6]
    }
  ' "$1"
}

hf_table_cell() { hf_table_rows "$1" | awk -F'\t' -v s="$2" -v i="$3" '$1==s {print $i}'; }

hf_table_row_task()     { hf_table_cell "$1" "$2" 2; }
hf_table_row_result()   { hf_table_cell "$1" "$2" 5; }
hf_table_row_question() { hf_table_cell "$1" "$2" 6; }
hf_table_row_status()   { hf_table_cell "$1" "$2" 3 | awk '{print $NF}'; }

hf_table_has_row() { hf_table_rows "$1" | cut -f1 | grep -Fxq "$2"; }

# hf_table_set_row <file> <slug> <task-md> <status> <result-md> <question-md>
# Prints the new comment body to stdout. Touches exactly one row.
hf_table_set_row() {
  local file="$1" slug="$2" task="$3" status="$4" result="$5" question="${6:-}"
  local emoji row updated
  emoji=$(hf_status_emoji "$status")
  updated=$(hf_now_utc)
  [ -n "$task" ] || task='—'
  [ -n "$result" ] || result='—'
  [ -n "$question" ] || question='—'
  row=$(printf '| `%s` | %s | %s %s | %s | %s | %s |' \
        "$slug" "$task" "$emoji" "$status" "$updated" "$result" "$question")

  awk -v slug="$slug" -v row="$row" -v sep="$HF_TABLE_SEP" '
    BEGIN { prefix = "| `" slug "` |"; plen = length(prefix); replaced = 0 }
    {
      lines[NR] = $0
      if (substr($0, 1, plen) == prefix) { hit[NR] = 1; replaced = 1 }
      if (substr($0, 1, 3) == "| `") lastrow = NR
      if ($0 == sep) sepline = NR
    }
    END {
      insert_after = (lastrow ? lastrow : sepline)
      for (i = 1; i <= NR; i++) {
        if (hit[i]) { print row } else { print lines[i] }
        if (!replaced && i == insert_after) print row
      }
      if (!replaced && !insert_after) { print ""; print row }
    }
  ' "$file"
}
