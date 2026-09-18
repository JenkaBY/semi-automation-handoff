#!/usr/bin/env bash
# lib/retry.sh — optimistic concurrency for editing a comment.
#
# Protocol (at most 3 attempts, backoff 1s/2s/4s plus jitter):
#   1. GET the comment → body and updated_at (the version)
#   2. the mutator changes ONLY its own part of the body
#   3. GET again: version changed → back to step 1
#   4. PATCH
#   5. verify with GET: our change is in place
#   6. attempts exhausted → exit 75; the caller must mark BLOCKED and call a human

HF_RETRY_MAX="${HF_RETRY_MAX:-3}"

hf_strip_trailing_nl() { printf '%s' "$(cat "$1")"; }

hf_comment_fetch_body() { hf_api GET "repos/$1/issues/comments/$2" --jq '.body'; }
hf_comment_fetch_ver()  { hf_api GET "repos/$1/issues/comments/$2" --jq '.updated_at'; }

hf_backoff() {
  [ -n "${HF_NO_SLEEP:-}" ] && return 0
  local n="$1" base jitter
  base=$(( 1 << (n - 1) ))
  jitter=$(( (RANDOM % 700) + 100 ))
  sleep "$(awk -v b="$base" -v j="$jitter" 'BEGIN{printf "%.2f", b + j/1000}')" 2>/dev/null || sleep "$base"
}

# hf_comment_update_optimistic <repo> <comment_id> <mutator> [verifier]
#   mutator:   <command> <input-file> → new body on stdout
#   verifier:  <command> <file> → 0 if our change is present (default: exact match)
hf_comment_update_optimistic() {
  local repo="$1" cid="$2" mutate="$3" verify="${4:-}"
  local attempt=1 tmp cur new ver ver2 got
  tmp=$(mktemp -d) || return "$HF_EX_PRECOND"
  cur="$tmp/cur"; new="$tmp/new"; got="$tmp/got"

  while [ "$attempt" -le "$HF_RETRY_MAX" ]; do
    hf_comment_fetch_body "$repo" "$cid" > "$cur" || { rm -rf "$tmp"; return "$HF_EX_NOTFOUND"; }
    ver=$(hf_comment_fetch_ver "$repo" "$cid") || { rm -rf "$tmp"; return "$HF_EX_NOTFOUND"; }
    hf_strip_trailing_nl "$cur" > "$cur.n" && mv "$cur.n" "$cur"

    if ! eval "$mutate \"\$cur\"" > "$new"; then
      rm -rf "$tmp"; return "$HF_EX_CONFIG"
    fi
    hf_strip_trailing_nl "$new" > "$new.n" && mv "$new.n" "$new"

    if cmp -s "$cur" "$new"; then
      hf_debug "nothing changed, no PATCH needed"
      rm -rf "$tmp"; return 0
    fi

    # Step 3: the version may have moved while we were preparing the new body
    ver2=$(hf_comment_fetch_ver "$repo" "$cid") || { rm -rf "$tmp"; return "$HF_EX_NOTFOUND"; }
    if [ "$ver" != "$ver2" ]; then
      hf_debug "version changed before write ($ver → $ver2), re-reading"
      hf_backoff "$attempt"; attempt=$((attempt + 1)); continue
    fi

    if ! hf_api PATCH "repos/$repo/issues/comments/$cid" -F "body=@$new" >/dev/null; then
      hf_debug "PATCH failed, attempt $attempt"
      hf_backoff "$attempt"; attempt=$((attempt + 1)); continue
    fi

    # Step 5: verification
    hf_comment_fetch_body "$repo" "$cid" > "$got" || { rm -rf "$tmp"; return "$HF_EX_NOTFOUND"; }
    hf_strip_trailing_nl "$got" > "$got.n" && mv "$got.n" "$got"
    if [ -n "$verify" ]; then
      if eval "$verify \"\$got\""; then rm -rf "$tmp"; return 0; fi
    elif cmp -s "$got" "$new"; then
      rm -rf "$tmp"; return 0
    fi

    hf_debug "verification failed, attempt $attempt"
    hf_backoff "$attempt"; attempt=$((attempt + 1))
  done

  rm -rf "$tmp"
  hf_err "Conflict on comment $repo#$cid not resolved in $HF_RETRY_MAX attempts."
  hf_err "Mark the task BLOCKED and hand conflict resolution to a human."
  return "$HF_EX_CONFLICT"
}
