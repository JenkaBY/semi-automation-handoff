# hf accept --ref REF [--force]
# Orchestrator side: finish the chain. Quality is NOT reviewed: a task counts as
# finished once the assignee has closed it.
# The parent task is closed only when nothing is BLOCKED and every dependent task
# is finished (DONE or CANCELLED). Otherwise the command refuses and lists them.
# Output: accept<TAB>repo#N<TAB>closed|blocked|pending

ref=""; force=0
while [ $# -gt 0 ]; do
  case "$1" in
    --ref) ref="$2"; shift 2 ;;
    --force) force=1; shift ;;
    *) hf_die "$HF_EX_CONFIG" "accept: unknown argument $1" ;;
  esac
done

hf_gh_require
hf_config_load
hf_ref_required "$ref"
p_repo="$HF_REF_REPO"; p_num="$HF_REF_NUM"

rid=$(gh api "repos/$p_repo/issues/$p_num/comments" --paginate \
       --jq '.[] | select(.body | startswith("<!-- handoff:routing")) | .id' 2>/dev/null | head -1)
[ -n "$rid" ] || hf_die "$HF_EX_NOTFOUND" \
  "$(hf_ref_str) has no routing comment — it is not a handoff parent task."

body=$(mktemp)
hf_comment_fetch_body "$p_repo" "$rid" > "$body"

blocked=""; pending=""
while IFS=$'\t' read -r slug task status updated result question; do
  [ -n "$slug" ] || continue
  num=$(printf '%s' "$task" | sed -n 's/.*\[#\([0-9][0-9]*\)\].*/\1/p')
  st="$(printf '%s' "$status" | awk '{print $NF}')"
  [ -n "$num" ] && st=$(hf_issue_status "$slug" "$num")
  printf '\t%s#%s\t%s %s\n' "$slug" "$num" "$(hf_status_emoji "$st")" "$st"
  case "$st" in
    BLOCKED)        blocked="$blocked $slug#$num" ;;
    DONE|CANCELLED) : ;;
    *)              pending="$pending $slug#$num" ;;
  esac
done < <(hf_table_rows "$body")
rm -f "$body"

if [ "$force" = 0 ] && [ -n "$blocked" ]; then
  printf 'accept\t%s#%s\tblocked\n' "$p_repo" "$p_num"
  hf_err "Blocked tasks:$blocked — answer their questions first (hf answer)."
  exit "$HF_EX_CONFIG"
fi
if [ "$force" = 0 ] && [ -n "$pending" ]; then
  printf 'accept\t%s#%s\tpending\n' "$p_repo" "$p_num"
  hf_err "Unfinished tasks:$pending — wait for the assignees to close them."
  exit "$HF_EX_CONFIG"
fi

msg=$(mktemp)
printf '✅ Every delegated task is finished. Chain closed.\n' > "$msg"
hf_comment_create "$p_repo" "$p_num" "$msg" >/dev/null 2>&1 || hf_warn "Could not add the closing comment"
rm -f "$msg"

gh issue close "$p_num" -R "$p_repo" -r completed >/dev/null 2>&1 \
  || hf_die "$HF_EX_PRECOND" "Could not close $p_repo#$p_num (triage access or higher is required)"

printf 'accept\t%s#%s\tclosed\n' "$p_repo" "$p_num"
exit 0
