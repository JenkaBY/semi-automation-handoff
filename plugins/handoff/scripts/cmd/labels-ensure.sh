# hf labels-ensure [--repo SLUG]
# Idempotently creates the two service labels. Statuses are NOT labels — they are
# reactions; labels exist only where gh can filter:
#   agent-task     — incoming tasks (/handoff:inbox)
#   handoff:parent — parent tasks (/handoff:check without a reference)

repo=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;
    *) hf_die "$HF_EX_CONFIG" "labels-ensure: unknown argument $1" ;;
  esac
done

hf_gh_require
hf_config_load
repo=${repo:-${HANDOFF_REPO:-$(hf_gh_current_repo)}}
[ -n "$repo" ] || hf_die "$HF_EX_CONFIG" "Repository could not be determined."

ensure() {
  gh label create "$1" -R "$repo" -c "$2" -d "$3" --force >/dev/null 2>&1 \
    && hf_log "ok	$1" \
    || { hf_warn "could not create label $1 in $repo"; return 1; }
}

rc=0
ensure "$HANDOFF_LABEL_TASK"   "0052cc" "Task for this repository's agent (handoff)" || rc=$HF_EX_PRECOND
ensure "$HANDOFF_LABEL_PARENT" "c5def5" "Handoff parent task: carries the result and routing comments" || rc=$HF_EX_PRECOND
exit "$rc"
