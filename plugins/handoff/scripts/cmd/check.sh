# hf check [--ref REF] [--render]
# Orchestrator side: summary of delegated tasks. Read-only unless --render is given
# (then the table is rebuilt from reactions).
# Quality is not judged: a closed task counts as finished.
# Output: PARENT / one line per task / SUMMARY

ref=""; render=0
while [ $# -gt 0 ]; do
  case "$1" in
    --ref) ref="$2"; shift 2 ;;
    --render) render=1; shift ;;
    *) hf_die "$HF_EX_CONFIG" "check: unknown argument $1" ;;
  esac
done

hf_gh_require
hf_config_load
repo=${HANDOFF_REPO:-$(hf_gh_current_repo)}

if [ -n "$ref" ]; then
  hf_ref_required "$ref"
  parents="$HF_REF_REPO#$HF_REF_NUM"
else
  parents=$(gh issue list -R "$repo" -l "$HANDOFF_LABEL_PARENT" --state open --limit 30 \
              --json number --jq ".[] | \"$repo#\" + (.number|tostring)" 2>/dev/null)
  [ -n "$parents" ] || { hf_note "No open parent tasks labelled $HANDOFF_LABEL_PARENT."; exit 0; }
fi

stale_days=${HANDOFF_STALE_DAYS:-3}
now=$(date -u +%s)
t_new=0; t_wip=0; t_blocked=0; t_done=0; t_cancelled=0

for p in $parents; do
  p_repo=${p%%#*}; p_num=${p##*#}
  rid=$(gh api "repos/$p_repo/issues/$p_num/comments" --paginate \
         --jq '.[] | select(.body | startswith("<!-- handoff:routing")) | .id' 2>/dev/null | head -1)
  title=$(gh issue view "$p_num" -R "$p_repo" --json title --jq '.title' 2>/dev/null)
  if [ -z "$rid" ]; then
    printf 'PARENT\t%s\t%s\t(no routing comment)\n' "$p" "$title"
    continue
  fi
  printf 'PARENT\t%s\t%s\t%s\n' "$p" "$title" "$(hf_comment_url "$p_repo" "$p_num" "$rid")"

  body=$(mktemp)
  hf_comment_fetch_body "$p_repo" "$rid" > "$body"
  while IFS=$'\t' read -r slug task status updated result question; do
    [ -n "$slug" ] || continue
    num=$(printf '%s' "$task" | sed -n 's/.*\[#\([0-9][0-9]*\)\].*/\1/p')
    st=$(printf '%s' "$status" | awk '{print $NF}')
    flag=""; prs=""
    if [ -n "$num" ]; then
      facts=$(hf_issue_facts "$slug" "$num")
      if [ -n "$facts" ]; then
        istate=$(printf '%s' "$facts" | cut -f1)
        iupd=$(printf '%s' "$facts" | cut -f3)
        prs=$(printf '%s' "$facts" | cut -f4)
        real=$(hf_status_resolve "$(printf '%s' "$facts" | cut -f2)" "$istate")
        [ "$real" != "$st" ] && { flag="$flag ⟲stale-table($st→$real)"; st="$real"; }
        upd_s=$(hf_date_epoch "$iupd" 2>/dev/null || printf '')
        if [ -n "$upd_s" ] && { [ "$st" = "WIP" ] || [ "$st" = "BLOCKED" ]; }; then
          age=$(( (now - upd_s) / 86400 ))
          [ "$age" -ge "$stale_days" ] && flag="$flag ⏳stalled(${age}d)"
        fi
        updated=$(printf '%s' "$iupd" | cut -c1-10)
      else
        flag="$flag ⚠no-access"
      fi
    fi
    case "$st" in
      NEW) t_new=$((t_new+1)) ;;
      WIP) t_wip=$((t_wip+1)) ;;
      BLOCKED) t_blocked=$((t_blocked+1)) ;;
      DONE) t_done=$((t_done+1)) ;;
      CANCELLED) t_cancelled=$((t_cancelled+1)) ;;
    esac
    [ "$st" = "DONE" ] && [ -z "$prs" ] && flag="$flag ⚠no-PR"
    [ "$question" = "—" ] && question=""
    printf '\t%s#%s\t%s %s\t%s\t%s\t%s%s\n' "$slug" "$num" "$(hf_status_emoji "$st")" "$st" \
      "$updated" "${prs:-—}" "${question:-—}" "$flag"
  done < <(hf_table_rows "$body")
  rm -f "$body"

  if [ "$render" = 1 ]; then
    ( . "$HF_SCRIPTS_DIR/cmd/routing-render.sh" --ref "$p" ) >/dev/null 2>&1 \
      && printf '\trouting-render\tok\n' || printf '\trouting-render\tfail\n'
  fi
done

printf 'SUMMARY\tNEW=%s WIP=%s BLOCKED=%s DONE=%s CANCELLED=%s\n' \
  "$t_new" "$t_wip" "$t_blocked" "$t_done" "$t_cancelled"
[ "$t_blocked" -gt 0 ] && hf_note "Some tasks are blocked — answer them: hf answer --ref <repo#N> --body-file <file>"
[ "$t_new" -eq 0 ] && [ "$t_wip" -eq 0 ] && [ "$t_blocked" -eq 0 ] && \
  hf_note "Every delegated task is finished — close the chain: hf accept --ref <parent task>"
exit 0
