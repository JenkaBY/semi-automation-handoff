# hf task-create --target SLUG --title T --body-file F --routing URL --context URL
#                [--path P] [--labels a,b] [--chain C]
# Creates a dependent task in a neighbouring repository.
# Checks before writing: delegation cycle, depth, membership in PEERS,
# idempotency (one task per "chain + repository" pair).
# Output: task<TAB>target#N<TAB>url<TAB>created|reused

target=""; title=""; bodyfile=""; routing=""; context=""; path=""; extra=""; chain=""
while [ $# -gt 0 ]; do
  case "$1" in
    --target) target="$2"; shift 2 ;;
    --title) title="$2"; shift 2 ;;
    --body-file) bodyfile="$2"; shift 2 ;;
    --routing) routing="$2"; shift 2 ;;
    --context) context="$2"; shift 2 ;;
    --path) path="$2"; shift 2 ;;
    --labels) extra="$2"; shift 2 ;;
    --chain) chain="$2"; shift 2 ;;
    *) hf_die "$HF_EX_CONFIG" "task-create: unknown argument $1" ;;
  esac
done

hf_gh_require
hf_config_load --required
[ -n "$target" ] || hf_die "$HF_EX_CONFIG" "task-create: --target owner/repo required"
[ -n "$title" ]  || hf_die "$HF_EX_CONFIG" "task-create: --title required"
[ -f "$bodyfile" ] || hf_die "$HF_EX_CONFIG" "task-create: --body-file not found"

hf_resolve_ref "$routing" || hf_die "$HF_EX_CONFIG" "task-create: --routing must point at the routing comment"
[ -n "$HF_REF_COMMENT" ] || hf_die "$HF_EX_CONFIG" "task-create: --routing has no #issuecomment-<id>"
parent_repo="$HF_REF_REPO"; parent_num="$HF_REF_NUM"; routing_id="$HF_REF_COMMENT"

me=${HANDOFF_REPO:-$(hf_gh_current_repo)}
[ "$target" = "$me" ] && hf_die "$HF_EX_GRAPH" "task-create: cannot delegate to your own repository ($me)."
hf_is_peer "$target" || hf_die "$HF_EX_CONFIG" \
  "task-create: $target is not in HANDOFF_PEERS. Add it via /handoff:init — writing to undeclared repositories is refused."

# Delegation path and cycle protection
[ -n "$path" ] || path="$me"
if hf_path_contains "$path" "$target"; then
  hf_die "$HF_EX_GRAPH" \
    "Delegation cycle: $target is already on the path «$path». Use a BLOCKED question and /handoff:answer instead of a new task."
fi
newpath=$(hf_path_append "$path" "$target")
depth=$(hf_path_depth "$newpath")
[ "$depth" -le "${HANDOFF_MAX_DEPTH:-3}" ] || hf_die "$HF_EX_GRAPH" \
  "Maximum chain depth exceeded (${HANDOFF_MAX_DEPTH:-3}): «$newpath»."

# Current routing comment: both the chain and idempotency come from here
rbody=$(mktemp)
hf_comment_fetch_body "$parent_repo" "$routing_id" > "$rbody" \
  || hf_die "$HF_EX_NOTFOUND" "Could not read the routing comment $routing"
[ -n "$chain" ] || chain=$(hf_table_chain "$rbody")
[ -n "$chain" ] || chain=$(hf_chain_new)
key=$(hf_key "$chain" "$target")
existing=$(hf_table_row_task "$rbody" "$target" | sed -n 's/.*\[#\([0-9][0-9]*\)\].*/\1/p')

tmp=$(mktemp)
{
  printf '**Context:** [result in %s#%s](%s) · **Status goes here:** [routing comment](%s)\n\n' \
         "$parent_repo" "$parent_num" "$context" "$routing"
  cat "$bodyfile"
  printf '\n'
  hf_meta_block "$chain" "$key" "$parent_repo#$parent_num" "$context" "$routing" \
                "$newpath" "$depth" "${HANDOFF_PROTOCOL:-1}" "$(hf_plugin_version)"
} > "$tmp"

labels="$HANDOFF_LABEL_TASK"
[ -n "$extra" ] && labels="$labels,$extra"

if [ -n "$existing" ]; then
  gh issue edit "$existing" -R "$target" --body-file "$tmp" >/dev/null 2>&1 \
    || hf_die "$HF_EX_PRECOND" "Could not update the existing task $target#$existing"
  num="$existing"; mode="reused"
else
  url=$(gh issue create -R "$target" -t "$title" -F "$tmp" -l "$labels" 2>&1) \
    || hf_die "$HF_EX_PRECOND" "Could not create a task in $target: $url"
  num=${url##*/}
  mode="created"
  link=$(mktemp)
  printf '📌 Status for this task is written to the [routing comment](%s) in `%s#%s`.\n' \
         "$routing" "$parent_repo" "$parent_num" > "$link"
  hf_comment_create "$target" "$num" "$link" >/dev/null 2>&1 \
    || hf_warn "Could not add the routing link comment to $target#$num"
  rm -f "$link"
fi
rm -f "$tmp" "$rbody"

if [ "$mode" = "created" ]; then
  HF_SLUG="$target"; HF_STATUS="NEW"
  HF_TASK="[#$num]($(hf_issue_url "$target" "$num"))"; HF_RESULT=""
  __hf_tc_mutate() { hf_table_set_row "$1" "$HF_SLUG" "$HF_TASK" "$HF_STATUS" "$HF_RESULT" ""; }
  __hf_tc_verify() { [ "$(hf_table_row_status "$1" "$HF_SLUG")" = "$HF_STATUS" ]; }
  hf_comment_update_optimistic "$parent_repo" "$routing_id" __hf_tc_mutate __hf_tc_verify \
    || hf_warn "Task created, but its routing row was not updated — run: hf routing-render --ref $parent_repo#$parent_num"
fi

printf 'task\t%s#%s\t%s\t%s\n' "$target" "$num" "$(hf_issue_url "$target" "$num")" "$mode"
exit 0
