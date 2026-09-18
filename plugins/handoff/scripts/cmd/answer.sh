# hf answer --ref REF --body-file F [--status CODE]
# Back channel. The answer is appended TO THE SAME question comment — no separate
# comment is created, so question and answer are always read together.
# An answered question is marked with a 👍 reaction on the comment itself.
# REF is either a question comment (…#issuecomment-123) or a task
# (then the last unanswered question comment is used).
# Output: answer<TAB>repo#N<TAB>url<TAB>CODE<TAB>routing:ok|routing:fail|routing:none

ref=""; bodyfile=""; status="NEW"
while [ $# -gt 0 ]; do
  case "$1" in
    --ref) ref="$2"; shift 2 ;;
    --body-file) bodyfile="$2"; shift 2 ;;
    --status) status="$2"; shift 2 ;;
    *) hf_die "$HF_EX_CONFIG" "answer: unknown argument $1" ;;
  esac
done

hf_gh_require
hf_config_load
hf_status_valid "$status" || hf_die "$HF_EX_CONFIG" "answer: unknown status «$status»"
hf_ref_required "$ref"
[ -f "$bodyfile" ] || hf_die "$HF_EX_CONFIG" "answer: --body-file not found"
task_repo="$HF_REF_REPO"; task_num="$HF_REF_NUM"; cid="$HF_REF_COMMENT"

if [ -z "$cid" ]; then
  cid=$(gh api "repos/$task_repo/issues/$task_num/comments" --paginate \
        --jq '.[] | select(.body | startswith("<!-- handoff:question")) | select(.body | contains("### 💬 Answer") | not) | .id' \
        2>/dev/null | tail -1)
  [ -n "$cid" ] || hf_die "$HF_EX_NOTFOUND" \
    "No unanswered question comment in $task_repo#$task_num. Pass the comment URL explicitly."
fi

HF_ANSWER_FILE="$bodyfile"
__hf_ans_mutate() {
  cat "$1"
  printf '\n\n---\n### 💬 Answer · %s\n\n' "$(hf_now_utc)"
  cat "$HF_ANSWER_FILE"
}
__hf_ans_verify() { grep -q '^### 💬 Answer' "$1"; }

hf_comment_update_optimistic "$task_repo" "$cid" __hf_ans_mutate __hf_ans_verify
rc=$?
[ "$rc" -eq 0 ] || hf_die "$rc" "Could not append the answer to comment $cid — resolve it manually."

hf_comment_react "$task_repo" "$cid" "$HF_REACTION_ANSWERED"
url=$(hf_comment_url "$task_repo" "$task_num" "$cid")

body=$(mktemp)
gh issue view "$task_num" -R "$task_repo" --json body --jq '.body' > "$body" 2>/dev/null || :
routing=$(hf_meta_get "$body" routing); rm -f "$body"

hf_reaction_set "$task_repo" "$task_num" "$(hf_status_reaction "$status")"

rc_txt="routing:none"
if [ -n "$routing" ]; then
  set -- --routing "$routing" --slug "$task_repo" --status "$status" \
         --task "[#$task_num]($(hf_issue_url "$task_repo" "$task_num"))" --question "[question]($url)"
  if ( . "$HF_SCRIPTS_DIR/cmd/routing-set.sh" ) >/dev/null 2>&1; then rc_txt="routing:ok"; else rc_txt="routing:fail"; fi
fi

printf 'answer\t%s#%s\t%s\t%s\t%s\n' "$task_repo" "$task_num" "$url" "$status" "$rc_txt"
exit 0
