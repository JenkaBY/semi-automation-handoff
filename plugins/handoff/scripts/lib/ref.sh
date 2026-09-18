#!/usr/bin/env bash
# lib/ref.sh — parse a task reference in any accepted form.
#
#   42                                            issue in the current repository
#   #42                                           same
#   owner/repo#42                                 issue in the named repository
#   https://github.com/owner/repo/issues/42       same
#   .../issues/42#issuecomment-123                task plus a specific comment
#   -  or empty                                   the session's current task (.handoff/state.env)
#
# Result in: HF_REF_REPO, HF_REF_NUM, HF_REF_COMMENT

hf_resolve_ref() {
  local raw="${1:-}"
  HF_REF_REPO=""; HF_REF_NUM=""; HF_REF_COMMENT=""

  if [ -z "$raw" ] || [ "$raw" = "-" ]; then
    raw=$(hf_state_get HANDOFF_CURRENT_REF 2>/dev/null || true)
    [ -n "$raw" ] || return 1
  fi

  raw=${raw%/}
  case "$raw" in
    *'#issuecomment-'*)
      HF_REF_COMMENT=${raw##*#issuecomment-}
      raw=${raw%%#issuecomment-*}
      ;;
  esac

  case "$raw" in
    http://*|https://*)
      local rest=${raw#*://}
      rest=${rest#*/}                       # drop the host
      case "$rest" in
        */issues/*)
          HF_REF_REPO=${rest%%/issues/*}
          HF_REF_NUM=${rest##*/issues/}
          ;;
        */pull/*)
          HF_REF_REPO=${rest%%/pull/*}
          HF_REF_NUM=${rest##*/pull/}
          ;;
        *) return 1 ;;
      esac
      ;;
    */*'#'*)
      HF_REF_REPO=${raw%%#*}
      HF_REF_NUM=${raw##*#}
      ;;
    '#'*)
      HF_REF_NUM=${raw#\#}
      ;;
    *)
      HF_REF_NUM=$raw
      ;;
  esac

  HF_REF_NUM=${HF_REF_NUM%%[!0-9]*}
  case "$HF_REF_NUM" in ''|*[!0-9]*) return 1 ;; esac

  if [ -z "$HF_REF_REPO" ]; then
    HF_REF_REPO=${HANDOFF_REPO:-$(hf_gh_current_repo 2>/dev/null || true)}
  fi
  case "$HF_REF_REPO" in
    */*) : ;;
    *) return 1 ;;
  esac
  return 0
}

hf_ref_str() { printf '%s#%s' "$HF_REF_REPO" "$HF_REF_NUM"; }

# Resolve a reference and tell the user what it resolved to.
hf_ref_required() {
  if ! hf_resolve_ref "${1:-}"; then
    hf_die "$HF_EX_CONFIG" \
      "Cannot parse task reference «${1:-<empty>}». Accepted: 42 | #42 | owner/repo#42 | issue or comment URL."
  fi
  hf_note "→ $(hf_ref_str)"
  return 0
}

hf_ref_remember() { hf_state_set HANDOFF_CURRENT_REF "$1"; }
