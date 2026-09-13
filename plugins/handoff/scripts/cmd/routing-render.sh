# hf routing-render --ref REF
# Rebuilds the routing table from the source of truth — reactions on the dependent
# tasks and their open/closed state. This is what makes the table a cache:
# a lost write never loses system state.
# Output: one line per repository plus a summary.

ref=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ref) ref="$2"; shift 2 ;;
    *) hf_die "$HF_EX_CONFIG" "routing-render: unknown argument $1" ;;
  esac
done

hf_gh_require
hf_config_load
hf_ref_required "$ref"

rid=$(gh api "repos/$HF_REF_REPO/issues/$HF_REF_NUM/comments" --paginate \
       --jq '.[] | select(.body | startswith("<!-- handoff:routing")) | .id' 2>/dev/null | head -1)
[ -n "$rid" ] || hf_die "$HF_EX_NOTFOUND" "$(hf_ref_str) has no routing comment."

body=$(mktemp); truth=$(mktemp)
hf_comment_fetch_body "$HF_REF_REPO" "$rid" > "$body"

# The truth snapshot is taken once, before the write-retry loop.
while IFS=$'\t' read -r slug task status updated result question; do
  [ -n "$slug" ] || continue
  num=$(printf '%s' "$task" | sed -n 's/.*\[#\([0-9][0-9]*\)\].*/\1/p')
  [ -n "$num" ] || continue
  st=$(hf_issue_status "$slug" "$num") || continue
  [ -n "$st" ] || st=$(printf '%s' "$status" | awk '{print $NF}')
  printf '%s\t%s\t%s\n' "$slug" "$st" "$num" >> "$truth"
done < <(hf_table_rows "$body")

__hf_rr_mutate() {
  local f="$1" tmp slug st num
  tmp=$(mktemp); cp "$f" "$tmp"
  while IFS=$'\t' read -r slug st num; do
    [ -n "$slug" ] || continue
    hf_table_set_row "$tmp" "$slug" "$(hf_table_row_task "$tmp" "$slug")" "$st" \
      "$(hf_table_row_result "$tmp" "$slug")" "$(hf_table_row_question "$tmp" "$slug")" > "$tmp.n"
    mv "$tmp.n" "$tmp"
  done < "$truth"
  cat "$tmp"; rm -f "$tmp"
}

__hf_rr_verify() {
  local f="$1" slug st num ok=0
  while IFS=$'\t' read -r slug st num; do
    [ -n "$slug" ] || continue
    [ "$(hf_table_row_status "$f" "$slug")" = "$st" ] || ok=1
  done < "$truth"
  return "$ok"
}

hf_comment_update_optimistic "$HF_REF_REPO" "$rid" __hf_rr_mutate __hf_rr_verify
rc=$?
awk -F'\t' '{printf "%s\t%s\t#%s\n", $1, $2, $3}' "$truth"
printf 'routing-render\t%s\t%s\n' "$(hf_ref_str)" "$([ $rc -eq 0 ] && echo ok || echo fail)"
rm -f "$body" "$truth"
exit "$rc"
