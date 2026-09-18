# hf question-status --ref REF
# Assignee side: check your own question comment before resuming work.
# REF is either a comment URL or a task (then the last question comment is used).
#
# Output: question<TAB>url<TAB>pending|answered|reacted-no-answer
#   pending            — no answer, no reaction: keep waiting (exit 0)
#   answered           — the answer is printed too (exit 0)
#   reacted-no-answer  — 👍 is there but the comment has no answer: stop (exit 7)

ref=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ref) ref="$2"; shift 2 ;;
    *) hf_die "$HF_EX_CONFIG" "question-status: unknown argument $1" ;;
  esac
done

hf_gh_require
hf_config_load
hf_ref_required "$ref"
repo="$HF_REF_REPO"; num="$HF_REF_NUM"; cid="$HF_REF_COMMENT"

if [ -z "$cid" ]; then
  cid=$(gh api "repos/$repo/issues/$num/comments" --paginate \
        --jq '.[] | select(.body | startswith("<!-- handoff:question")) | .id' 2>/dev/null | tail -1)
  [ -n "$cid" ] || hf_die "$HF_EX_NOTFOUND" "No question comment in $repo#$num."
fi

url=$(hf_comment_url "$repo" "$num" "$cid")
tmp=$(mktemp)
hf_comment_fetch_body "$repo" "$cid" > "$tmp" || { rm -f "$tmp"; hf_die "$HF_EX_NOTFOUND" "Comment $cid cannot be read."; }

has_answer=0; grep -q '^### 💬 Answer' "$tmp" && has_answer=1
has_react=0;  hf_comment_has_reaction "$repo" "$cid" "$HF_REACTION_ANSWERED" && has_react=1

if [ "$has_answer" = 1 ]; then
  printf 'question\t%s\tanswered\n' "$url"
  printf -- '---ANSWER---\n'
  sed -n '/^### 💬 Answer/,$p' "$tmp" | tail -n +2
  rm -f "$tmp"; exit 0
fi

rm -f "$tmp"
if [ "$has_react" = 1 ]; then
  printf 'question\t%s\treacted-no-answer\n' "$url"
  hf_err "The question comment carries 👍 but contains no answer text."
  hf_err "Do not resume the task: ask a human to append the answer to that same comment."
  exit "$HF_EX_AMBIGUOUS"
fi

printf 'question\t%s\tpending\n' "$url"
exit 0
