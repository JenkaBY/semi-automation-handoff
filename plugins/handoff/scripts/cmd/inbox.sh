# hf inbox [--all] [--repo SLUG] [--limit N]
# Incoming tasks for this agent. One GraphQL request brings the list, states and
# reactions at once — statuses live in reactions and polling them per issue is costly.
# Output: #N<TAB>emoji STATUS<TAB>updated<TAB>from<TAB>title

states='[OPEN]'; repo=""; limit=30
while [ $# -gt 0 ]; do
  case "$1" in
    --all) states='[OPEN, CLOSED]'; shift ;;
    --repo) repo="$2"; shift 2 ;;
    --limit) limit="$2"; shift 2 ;;
    *) hf_die "$HF_EX_CONFIG" "inbox: unknown argument $1" ;;
  esac
done

hf_gh_require
hf_config_load
repo=${repo:-${HANDOFF_REPO:-$(hf_gh_current_repo)}}
[ -n "$repo" ] || hf_die "$HF_EX_CONFIG" "Repository could not be determined."
owner=${repo%%/*}; name=${repo##*/}

query="query(\$owner:String!,\$name:String!,\$label:String!,\$n:Int!){
  repository(owner:\$owner,name:\$name){
    issues(first:\$n, states:$states, labels:[\$label], orderBy:{field:UPDATED_AT,direction:DESC}){
      nodes{ number title state updatedAt body reactions(first:30){nodes{content}} }
    }
  }
}"
jqt='.data.repository.issues.nodes[] | [ (.number|tostring), (.updatedAt|split("T")[0]), ((([.reactions.nodes[].content]|join(" "))) | if . == "" then "-" else . end), .state, (((.body // "")|split("\n")|map(select(startswith("from:")))|(first // "")) | if . == "" then "-" else . end), .title ] | @tsv'

raw=$(gh api graphql -f query="$query" -F owner="$owner" -F name="$name" \
        -F label="$HANDOFF_LABEL_TASK" -F n="$limit" --jq "$jqt" 2>/dev/null) \
  || hf_die "$HF_EX_PRECOND" "Could not fetch the task list from $repo"

if [ -z "$raw" ]; then
  hf_note "No incoming tasks ($repo · label=$HANDOFF_LABEL_TASK)"
  exit 0
fi

printf '%s\n' "$raw" | while IFS=$'\t' read -r num updated reactions state from title; do
  [ -n "$num" ] || continue
  [ "$reactions" = "-" ] && reactions=""
  [ "$from" = "-" ] && from=""
  rl=""
  for r in $reactions; do rl="$rl $(hf_reaction_from_graphql "$r")"; done
  st=$(hf_status_resolve "$rl" "$state")
  from=$(printf '%s' "$from" | sed 's/^from:[[:space:]]*//' | tr -d '\r')
  printf '#%s\t%s %s\t%s\t%s\t%s\n' "$num" "$(hf_status_emoji "$st")" "$st" "$updated" "$from" "$title"
done
exit 0
