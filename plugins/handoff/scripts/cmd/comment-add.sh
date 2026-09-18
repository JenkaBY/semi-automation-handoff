# hf comment-add --ref REF --body-file F [--kind result|question|note]
# Result comments are append-only. A question comment is later extended with the
# answer in place (hf answer) — a separate answer comment is never created.
# Output: comment<TAB>id<TAB>url

ref=""; bodyfile=""; kind="result"
while [ $# -gt 0 ]; do
  case "$1" in
    --ref) ref="$2"; shift 2 ;;
    --body-file) bodyfile="$2"; shift 2 ;;
    --kind) kind="$2"; shift 2 ;;
    *) hf_die "$HF_EX_CONFIG" "comment-add: unknown argument $1" ;;
  esac
done

hf_gh_require
hf_config_load
hf_ref_required "$ref"
[ -f "$bodyfile" ] || hf_die "$HF_EX_CONFIG" "comment-add: --body-file not found"

case "$kind" in
  result)   icon="📦"; caption="Result" ;;
  question) icon="❓"; caption="Question" ;;
  note)     icon="📝"; caption="Note" ;;
  *) hf_die "$HF_EX_CONFIG" "comment-add: unknown --kind $kind (result|question|note)" ;;
esac

me=${HANDOFF_REPO:-$(hf_gh_current_repo)}
tmp=$(mktemp)
{
  printf '<!-- handoff:%s v=1 repo=%s -->\n' "$kind" "$me"
  printf '### %s %s · `%s` · %s\n\n' "$icon" "$caption" "$me" "$(hf_now_utc)"
  cat "$bodyfile"
} > "$tmp"

id=$(hf_comment_create "$HF_REF_REPO" "$HF_REF_NUM" "$tmp") || {
  rm -f "$tmp"; hf_die "$HF_EX_PRECOND" "Could not add a comment to $(hf_ref_str)"; }
rm -f "$tmp"
printf 'comment\t%s\t%s\n' "$id" "$(hf_comment_url "$HF_REF_REPO" "$HF_REF_NUM" "$id")"
exit 0
