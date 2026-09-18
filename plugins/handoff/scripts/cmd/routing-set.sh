# hf routing-set --routing URL --slug SLUG --status CODE
#                [--task MD] [--result MD] [--question MD] [--clear-question]
# Updates EXACTLY ONE row of the routing comment under the row-ownership rule,
# with optimistic locking and three attempts (see lib/retry.sh).
# Columns that are not given keep their previous values.
# Output: routing-set<TAB>slug<TAB>status<TAB>ok|fail

routing=""; HF_SLUG=""; HF_STATUS=""; HF_TASK=""; HF_RESULT=""; HF_QUESTION=""; HF_QCLEAR=0
while [ $# -gt 0 ]; do
  case "$1" in
    --routing) routing="$2"; shift 2 ;;
    --slug) HF_SLUG="$2"; shift 2 ;;
    --status) HF_STATUS="$2"; shift 2 ;;
    --task) HF_TASK="$2"; shift 2 ;;
    --result) HF_RESULT="$2"; shift 2 ;;
    --question) HF_QUESTION="$2"; shift 2 ;;
    --clear-question) HF_QCLEAR=1; shift ;;
    *) hf_die "$HF_EX_CONFIG" "routing-set: unknown argument $1" ;;
  esac
done

hf_gh_require
hf_config_load
[ -n "$HF_SLUG" ] || hf_die "$HF_EX_CONFIG" "routing-set: --slug required"
hf_status_valid "$HF_STATUS" || hf_die "$HF_EX_CONFIG" "routing-set: unknown status «$HF_STATUS» (allowed: $HF_STATUSES)"
hf_resolve_ref "$routing" || hf_die "$HF_EX_CONFIG" "routing-set: --routing must point at the routing comment (…#issuecomment-123)"
[ -n "$HF_REF_COMMENT" ] || hf_die "$HF_EX_CONFIG" "routing-set: the reference has no #issuecomment-<id>"

__hf_rs_mutate() {
  local f="$1" task result question
  task="$HF_TASK";     [ -n "$task" ]   || task=$(hf_table_row_task "$f" "$HF_SLUG")
  result="$HF_RESULT"; [ -n "$result" ] || result=$(hf_table_row_result "$f" "$HF_SLUG")
  if [ "$HF_QCLEAR" = 1 ]; then
    question=""
  else
    question="$HF_QUESTION"; [ -n "$question" ] || question=$(hf_table_row_question "$f" "$HF_SLUG")
  fi
  hf_table_set_row "$f" "$HF_SLUG" "$task" "$HF_STATUS" "$result" "$question"
}

# Verify by meaning, not by bytes: our row is there and carries the wanted status.
__hf_rs_verify() {
  [ "$(hf_table_row_status "$1" "$HF_SLUG")" = "$HF_STATUS" ] || return 1
  if [ "$HF_QCLEAR" = 1 ]; then
    [ "$(hf_table_row_question "$1" "$HF_SLUG")" = "—" ] || return 1
  fi
  return 0
}

hf_comment_update_optimistic "$HF_REF_REPO" "$HF_REF_COMMENT" __hf_rs_mutate __hf_rs_verify
rc=$?
printf 'routing-set\t%s\t%s\t%s\n' "$HF_SLUG" "$HF_STATUS" "$([ $rc -eq 0 ] && echo ok || echo fail)"
exit "$rc"
