# hf status-set --ref REF --status CODE [--result-url URL] [--question-url URL]
#               [--clear-question] [--no-close]
# Assignee side: set the reaction on your own task, then your own row in the
# parent's routing comment. Source of truth is the reaction plus the issue state.
# DONE closes the task: a finished task is a closed task.
# Output: status<TAB>repo#N<TAB>CODE<TAB>routing:ok|routing:fail|routing:none

ref=""; status=""; result_url=""; question_url=""; qclear=0; noclose=0
while [ $# -gt 0 ]; do
  case "$1" in
    --ref) ref="$2"; shift 2 ;;
    --status) status="$2"; shift 2 ;;
    --result-url) result_url="$2"; shift 2 ;;
    --question-url) question_url="$2"; shift 2 ;;
    --clear-question) qclear=1; shift ;;
    --no-close) noclose=1; shift ;;
    *) hf_die "$HF_EX_CONFIG" "status-set: unknown argument $1" ;;
  esac
done

hf_gh_require
hf_config_load
hf_status_valid "$status" || hf_die "$HF_EX_CONFIG" "status-set: unknown status «$status» (allowed: $HF_STATUSES)"
hf_ref_required "$ref"
task_repo="$HF_REF_REPO"; task_num="$HF_REF_NUM"

body=$(mktemp)
gh issue view "$task_num" -R "$task_repo" --json body --jq '.body' > "$body" 2>/dev/null \
  || { rm -f "$body"; hf_die "$HF_EX_NOTFOUND" "Task $task_repo#$task_num not found."; }
routing=$(hf_meta_get "$body" routing)
proto=$(hf_meta_get "$body" protocol)
rm -f "$body"

if ! hf_meta_check_protocol "$proto"; then
  hf_die "$HF_EX_PROTOCOL" \
    "Protocol version mismatch: task says $proto, local is ${HANDOFF_PROTOCOL:-1}. Bring the plugin to the same version in every repository."
fi

hf_reaction_set "$task_repo" "$task_num" "$(hf_status_reaction "$status")"
hf_ref_remember "$task_repo#$task_num"

# "A finished task is a closed task"
if [ "$status" = "DONE" ] && [ "$noclose" = 0 ]; then
  gh issue close "$task_num" -R "$task_repo" -r completed >/dev/null 2>&1 \
    || hf_warn "Could not close $task_repo#$task_num (triage access or higher is required)"
elif [ "$status" = "WIP" ] || [ "$status" = "BLOCKED" ]; then
  gh issue reopen "$task_num" -R "$task_repo" >/dev/null 2>&1 || :
fi

if [ -z "$routing" ]; then
  printf 'status\t%s#%s\t%s\trouting:none\n' "$task_repo" "$task_num" "$status"
  hf_warn "The task carries no routing link — the status was set on the task only."
  exit 0
fi

set -- --routing "$routing" --slug "$task_repo" --status "$status" \
       --task "[#$task_num]($(hf_issue_url "$task_repo" "$task_num"))"
[ -n "$result_url" ]   && set -- "$@" --result "[result]($result_url)"
[ -n "$question_url" ] && set -- "$@" --question "[question]($question_url)"
[ "$qclear" = 1 ]      && set -- "$@" --clear-question

if ( . "$HF_SCRIPTS_DIR/cmd/routing-set.sh" ) >/dev/null 2>&1; then
  printf 'status\t%s#%s\t%s\trouting:ok\n' "$task_repo" "$task_num" "$status"
  exit 0
else
  rc=$?
  printf 'status\t%s#%s\t%s\trouting:fail\n' "$task_repo" "$task_num" "$status"
  if [ "$rc" -eq "$HF_EX_CONFLICT" ]; then
    hf_err "The routing row was not updated because of a conflict. The status on the task (reaction) is already set — that is the source of truth."
    hf_err "Next: tell a human and suggest running hf routing-render --ref <parent task>."
  fi
  exit "$rc"
fi
