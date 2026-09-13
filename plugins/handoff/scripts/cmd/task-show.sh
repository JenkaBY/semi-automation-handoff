# hf task-show --ref REF [--context] [--no-body]
# Compact view for the assignee agent: status (from reactions), metadata,
# linked PRs from the Development section, body.
# --context also pulls the result comment — the thing that replaces re-telling.

ref=""; want_context=0; want_body=1
while [ $# -gt 0 ]; do
  case "$1" in
    --ref) ref="$2"; shift 2 ;;
    --context) want_context=1; shift ;;
    --no-body) want_body=0; shift ;;
    *) hf_die "$HF_EX_CONFIG" "task-show: unknown argument $1" ;;
  esac
done

hf_gh_require
hf_config_load
hf_ref_required "$ref"

jqt='"TITLE\t" + .title + "\nURL\t" + .url + "\nLABELS\t" + ([.labels[].name] | join(",")) + "\n---BODY---\n" + .body'
tmp=$(mktemp)
gh issue view "$HF_REF_NUM" -R "$HF_REF_REPO" --json title,body,labels,state,url --jq "$jqt" > "$tmp" 2>/dev/null \
  || { rm -f "$tmp"; hf_die "$HF_EX_NOTFOUND" "Task $(hf_ref_str) not found."; }

sed -n '1,/^---BODY---$/p' "$tmp" | grep -v '^---BODY---$'

facts=$(hf_issue_facts "$HF_REF_REPO" "$HF_REF_NUM")
if [ -n "$facts" ]; then
  state=$(printf '%s' "$facts" | cut -f1)
  st=$(hf_status_resolve "$(printf '%s' "$facts" | cut -f2)" "$state")
  prs=$(printf '%s' "$facts" | cut -f4)
  printf 'STATUS\t%s %s\t(%s)\n' "$(hf_status_emoji "$st")" "$st" "$state"
  [ -n "$prs" ] && printf 'PR\t%s\n' "$prs"
fi

body=$(mktemp)
sed -n '/^---BODY---$/,$p' "$tmp" | tail -n +2 > "$body"

for k in chain key from context routing path depth protocol plugin; do
  v=$(hf_meta_get "$body" "$k")
  [ -n "$v" ] && printf '%s\t%s\n' "$(printf '%s' "$k" | tr '[:lower:]' '[:upper:]')" "$v"
done

proto=$(hf_meta_get "$body" protocol)
if ! hf_meta_check_protocol "$proto"; then
  printf 'PROTOCOL-MISMATCH\ttask protocol %s, local protocol %s\n' "$proto" "${HANDOFF_PROTOCOL:-1}"
fi

if [ "$want_body" = 1 ]; then
  printf '\n---TASK---\n'
  sed '/^<details><summary>/,$d' "$body"
fi

if [ "$want_context" = 1 ]; then
  ctx=$(hf_meta_get "$body" context)
  if [ -n "$ctx" ] && hf_resolve_ref "$ctx" && [ -n "$HF_REF_COMMENT" ]; then
    printf '\n---CONTEXT (result comment)---\n'
    hf_comment_fetch_body "$HF_REF_REPO" "$HF_REF_COMMENT" 2>/dev/null || printf '(could not read %s)\n' "$ctx"
  fi
fi

rm -f "$tmp" "$body"
exit 0
