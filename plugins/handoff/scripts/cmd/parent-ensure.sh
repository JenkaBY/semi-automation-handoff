# hf parent-ensure [--ref REF] --title T --body-file F [--repo SLUG]
# Creates a parent task, or marks an existing issue (including one a human filed).
# Output: parent<TAB>owner/repo#N<TAB>url

ref=""; title=""; bodyfile=""; repo=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ref) ref="$2"; shift 2 ;;
    --title) title="$2"; shift 2 ;;
    --body-file) bodyfile="$2"; shift 2 ;;
    --repo) repo="$2"; shift 2 ;;
    *) hf_die "$HF_EX_CONFIG" "parent-ensure: unknown argument $1" ;;
  esac
done

hf_gh_require
hf_config_load
repo=${repo:-${HANDOFF_REPO:-$(hf_gh_current_repo)}}

if [ -n "$ref" ]; then
  hf_ref_required "$ref"
  gh issue view "$HF_REF_NUM" -R "$HF_REF_REPO" --json number >/dev/null 2>&1 \
    || hf_die "$HF_EX_NOTFOUND" "Task $(hf_ref_str) not found."
  gh issue edit "$HF_REF_NUM" -R "$HF_REF_REPO" --add-label "$HANDOFF_LABEL_PARENT" >/dev/null 2>&1 \
    || hf_warn "Could not add label $HANDOFF_LABEL_PARENT to $(hf_ref_str)"
  num="$HF_REF_NUM"; repo="$HF_REF_REPO"
else
  [ -n "$title" ] || hf_die "$HF_EX_CONFIG" "parent-ensure: --title or --ref required"
  [ -f "$bodyfile" ] || hf_die "$HF_EX_CONFIG" "parent-ensure: --body-file not found"
  url=$(gh issue create -R "$repo" -t "$title" -F "$bodyfile" -l "$HANDOFF_LABEL_PARENT" 2>&1) \
    || hf_die "$HF_EX_PRECOND" "Could not create the parent task in $repo: $url"
  num=${url##*/}
fi

hf_ref_remember "$repo#$num"
printf 'parent\t%s#%s\t%s\n' "$repo" "$num" "$(hf_issue_url "$repo" "$num")"
exit 0
