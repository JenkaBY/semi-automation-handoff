# hf routing-ensure --ref REF [--chain CHAIN]
# Finds the routing comment on the parent task or creates it. There is exactly one
# such comment per parent task.
# Output: routing<TAB>id<TAB>chain<TAB>url

ref=""; chain=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ref) ref="$2"; shift 2 ;;
    --chain) chain="$2"; shift 2 ;;
    *) hf_die "$HF_EX_CONFIG" "routing-ensure: unknown argument $1" ;;
  esac
done

hf_gh_require
hf_config_load
hf_ref_required "$ref"

id=$(gh api "repos/$HF_REF_REPO/issues/$HF_REF_NUM/comments" --paginate \
      --jq '.[] | select(.body | startswith("<!-- handoff:routing")) | .id' 2>/dev/null | head -1)

if [ -n "$id" ]; then
  tmp=$(mktemp)
  hf_comment_fetch_body "$HF_REF_REPO" "$id" > "$tmp"
  chain=$(hf_table_chain "$tmp"); rm -f "$tmp"
else
  [ -n "$chain" ] || chain=$(hf_chain_new)
  tmp=$(mktemp)
  hf_table_body_new "$chain" > "$tmp"
  id=$(hf_comment_create "$HF_REF_REPO" "$HF_REF_NUM" "$tmp") || {
    rm -f "$tmp"; hf_die "$HF_EX_PRECOND" "Could not create the routing comment on $(hf_ref_str)"; }
  rm -f "$tmp"
fi

printf 'routing\t%s\t%s\t%s\n' "$id" "$chain" "$(hf_comment_url "$HF_REF_REPO" "$HF_REF_NUM" "$id")"
exit 0
