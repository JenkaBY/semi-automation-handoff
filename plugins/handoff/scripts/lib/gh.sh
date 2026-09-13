#!/usr/bin/env bash
# lib/gh.sh — a thin wrapper around the gh CLI. This is the only place that talks
# to the network, so tests can shadow `gh` in PATH and run fully offline.
# Works on Windows (Git Bash), Linux and macOS: POSIX utilities only,
# GNU/BSD differences are covered by fallbacks.

# Find gh when it is not in PATH (common on Windows: gh is installed but Git Bash
# does not know about it). The discovered path is wrapped in a gh() function.
hf_gh_bootstrap() {
  command -v gh >/dev/null 2>&1 && return 0
  local c
  if [ -n "${HANDOFF_GH:-}" ] && [ -x "${HANDOFF_GH}" ]; then
    HF_GH_BIN="$HANDOFF_GH"
  else
    for c in \
      "/c/Program Files/GitHub CLI/gh.exe" \
      "/c/Program Files (x86)/GitHub CLI/gh.exe" \
      "${LOCALAPPDATA:-$HOME/AppData/Local}/GitHubCLI/gh.exe" \
      "/usr/local/bin/gh" \
      "/usr/bin/gh" \
      "/opt/homebrew/bin/gh" \
      "/home/linuxbrew/.linuxbrew/bin/gh" ; do
      if [ -x "$c" ]; then HF_GH_BIN="$c"; break; fi
    done
  fi
  [ -n "${HF_GH_BIN:-}" ] || return 1
  gh() { "$HF_GH_BIN" "$@"; }
  hf_debug "gh found outside PATH: $HF_GH_BIN"
  return 0
}

hf_gh_require() {
  hf_gh_bootstrap || hf_die "$HF_EX_PRECOND" \
    "gh CLI not found. Install GitHub CLI (https://cli.github.com) or point HANDOFF_GH at it."
  if ! gh auth status >/dev/null 2>&1; then
    hf_die "$HF_EX_PRECOND" "gh is not authenticated. Run: gh auth login"
  fi
}

hf_gh_token_source() {
  if [ -n "${GH_TOKEN:-}" ];     then printf 'GH_TOKEN (environment variable)'; return; fi
  if [ -n "${GITHUB_TOKEN:-}" ]; then printf 'GITHUB_TOKEN (environment variable)'; return; fi
  printf 'gh auth login (keyring)'
}

hf_gh_current_repo() {
  [ -n "${HF_REPO_CACHE:-}" ] && { printf '%s' "$HF_REPO_CACHE"; return 0; }
  HF_REPO_CACHE=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null) || return 1
  [ -n "$HF_REPO_CACHE" ] || return 1
  printf '%s' "$HF_REPO_CACHE"
}

hf_gh_login() {
  [ -n "${HF_LOGIN_CACHE:-}" ] && { printf '%s' "$HF_LOGIN_CACHE"; return 0; }
  HF_LOGIN_CACHE=$(gh api user --jq .login 2>/dev/null) || return 1
  printf '%s' "$HF_LOGIN_CACHE"
}

# hf_api <method> <path> [extra gh api args...]
# Prints the response body. Network hiccups and 5xx are retried up to 3 times.
hf_api() {
  local method="$1" path="$2"; shift 2
  local attempt=1 out rc
  while : ; do
    if out=$(gh api --method "$method" "$path" "$@" 2>&1); then
      printf '%s' "$out"
      return 0
    fi
    rc=$?
    case "$out" in
      *"HTTP 5"*|*"timeout"*|*"connection reset"*|*"EOF"*|*"TLS handshake"*)
        if [ "$attempt" -lt 3 ]; then
          hf_debug "retry $attempt: $method $path"
          sleep "$attempt"; attempt=$((attempt + 1)); continue
        fi ;;
    esac
    printf '%s' "$out" >&2
    return "$rc"
  done
}

# Tell 403 (no permission) from 404 (no access / missing): ok|forbidden|notfound|error
hf_api_probe() {
  local path="$1" out
  if out=$(gh api "$path" 2>&1 >/dev/null); then printf 'ok'; return 0; fi
  case "$out" in
    *"HTTP 404"*) printf 'notfound' ;;
    *"HTTP 403"*|*"HTTP 401"*) printf 'forbidden' ;;
    *) printf 'error' ;;
  esac
}

hf_ratelimit_warn() {
  local rem
  rem=$(gh api rate_limit --jq .resources.core.remaining 2>/dev/null) || return 0
  [ -n "$rem" ] || return 0
  if [ "$rem" -lt 200 ] 2>/dev/null; then
    hf_warn "GitHub API budget left: $rem requests. Calls may start failing."
  fi
  return 0
}

# --- Comments ----------------------------------------------------------------

hf_comment_create() {
  hf_api POST "repos/$1/issues/$2/comments" -F "body=@$3" --jq '.id'
}

hf_comment_url() {
  printf 'https://github.com/%s/issues/%s#issuecomment-%s' "$1" "$2" "$3"
}

hf_issue_url() { printf 'https://github.com/%s/issues/%s' "$1" "$2"; }

# --- Reactions ---------------------------------------------------------------

# Reactions on the issue body (from all users), space separated
hf_issue_reactions() {
  gh api "repos/$1/issues/$2/reactions" --paginate --jq '.[].content' 2>/dev/null | tr '\n' ' '
}

hf_issue_state() {
  gh issue view "$2" -R "$1" --json state --jq '.state' 2>/dev/null
}

# Resolved status of a task: reactions plus issue state (single request)
hf_issue_status() {
  local facts
  facts=$(hf_issue_facts "$1" "$2") || return 1
  hf_status_resolve "$(printf %s "$facts" | cut -f2)" "$(printf %s "$facts" | cut -f1)"
}

# Drop the current user's status reactions and set the wanted one.
hf_reaction_set() {
  local repo="$1" issue="$2" want="$3" login id content
  login=$(hf_gh_login) || return 0
  while IFS=$'\t' read -r id content; do
    [ -n "$id" ] || continue
    [ "$content" = "$want" ] && continue
    hf_is_status_reaction "$content" && \
      hf_api DELETE "repos/$repo/issues/$issue/reactions/$id" >/dev/null 2>&1 || :
  done <<EOT
$(gh api "repos/$repo/issues/$issue/reactions" \
    --jq ".[] | select(.user.login==\"$login\") | \"\(.id)\t\(.content)\"" 2>/dev/null)
EOT
  [ -n "$want" ] || return 0
  hf_api POST "repos/$repo/issues/$issue/reactions" -f "content=$want" >/dev/null 2>&1 || \
    hf_warn "Could not set reaction $want on $repo#$issue"
  return 0
}

# Comment reactions — this is how an answered question comment is marked
hf_comment_reactions() {
  gh api "repos/$1/issues/comments/$2/reactions" --paginate --jq '.[].content' 2>/dev/null | tr '\n' ' '
}

hf_comment_react() {
  hf_api POST "repos/$1/issues/comments/$2/reactions" -f "content=$3" >/dev/null 2>&1 || \
    hf_warn "Could not set reaction $3 on comment $2"
  return 0
}

hf_comment_has_reaction() {
  case " $(hf_comment_reactions "$1" "$2") " in *" $3 "*) return 0 ;; *) return 1 ;; esac
}

# hf_issue_facts <repo> <num> — one request instead of three.
# Prints TSV: state, reactions (REST names, space separated), updated, PRs from Development
hf_issue_facts() {
  local jqt out
  jqt='[ .state, ([.reactionGroups[] | select(.users.totalCount > 0) | .content] | join(" ")), .updatedAt, ([.closedByPullRequestsReferences[] | "#\(.number)"] | join(" ")) ] | @tsv'
  out=$(gh issue view "$2" -R "$1" \
          --json state,reactionGroups,updatedAt,closedByPullRequestsReferences --jq "$jqt" 2>/dev/null) || return 1
  local state gql upd prs r rl=""
  state=$(printf '%s' "$out" | cut -f1)
  gql=$(printf '%s' "$out" | cut -f2)
  upd=$(printf '%s' "$out" | cut -f3)
  prs=$(printf '%s' "$out" | cut -f4)
  for r in $gql; do rl="$rl $(hf_reaction_from_graphql "$r")"; done
  printf '%s\t%s\t%s\t%s\n' "$state" "${rl# }" "$upd" "$prs"
}
