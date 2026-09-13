# hf doctor [--repo SLUG]
# Environment diagnostics. A FAIL line means the plugin cannot work yet.

target=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) target="$2"; shift 2 ;;
    *) hf_die "$HF_EX_CONFIG" "doctor: unknown argument $1" ;;
  esac
done

fail=0
row() { printf '%s\t%s\t%s\n' "$1" "$2" "$3"; }

# 1. gh
if hf_gh_bootstrap; then
  row "ok" "gh" "$(gh --version 2>/dev/null | head -1)"
else
  row "FAIL" "gh" "not found in PATH — https://cli.github.com"; fail=$HF_EX_PRECOND
fi

# 2. authentication and token source
if [ "$fail" = 0 ]; then
  if gh auth status >/dev/null 2>&1; then
    row "ok" "auth" "$(hf_gh_login 2>/dev/null || echo '?') · source: $(hf_gh_token_source)"
  else
    row "FAIL" "auth" "gh is not authenticated — run: gh auth login"; fail=$HF_EX_PRECOND
  fi
fi

hf_config_load
plugin_ver=$(hf_plugin_version)
row "ok" "plugin" "version $plugin_ver · protocol ${HANDOFF_PROTOCOL:-1}"

# 3. repository configuration
if [ "${HF_CONFIG_FOUND:-0}" = 1 ]; then
  row "ok" "config" "$(hf_config_file)"
else
  row "WARN" "config" "$(hf_config_file) is missing — run /handoff:init"
fi

repo=${target:-${HANDOFF_REPO:-}}
if [ -z "$repo" ]; then
  row "WARN" "repo" "current repository unknown (no git remote?)"
else
  row "ok" "repo" "$repo"
fi

[ "$fail" = 0 ] || exit "$fail"

# 4. labels
if [ -n "$repo" ]; then
  have=$(gh label list -R "$repo" --limit 200 --json name --jq '.[].name' 2>/dev/null || true)
  missing=""
  for l in "$HANDOFF_LABEL_TASK" "$HANDOFF_LABEL_PARENT"; do
    printf '%s\n' "$have" | grep -Fxq "$l" || missing="$missing $l"
  done
  if [ -z "$missing" ]; then
    row "ok" "labels" "all present"
  else
    row "WARN" "labels" "missing:$missing — run: hf labels-ensure"
  fi
fi

# 5. age of the neighbours map (local check, no network)
if [ -n "${HANDOFF_PEERS:-}" ]; then
  if age=$(hf_peers_lock_age_days) && [ -n "$age" ]; then
    if [ "$age" -ge "${HANDOFF_MAP_MAX_AGE_DAYS:-30}" ] 2>/dev/null; then
      row "WARN" "peers-map" "last refreshed ${age}d ago — run /handoff:refresh"
    else
      row "ok" "peers-map" "refreshed ${age}d ago"
    fi
  else
    row "WARN" "peers-map" "never refreshed — run /handoff:refresh"
  fi
fi

# 5. peers: access and effective permissions
for peer in ${HANDOFF_PEERS:-}; do
  case "$(hf_api_probe "repos/$peer")" in
    ok)
      perm=$(gh api "repos/$peer" --jq '.permissions | if .admin then "admin" elif .push then "write" elif .triage then "triage" else "read" end' 2>/dev/null || echo '?')
      issues=$(gh api "repos/$peer" --jq '.has_issues' 2>/dev/null || echo '?')
      if [ "$issues" = "true" ]; then
        case "$perm" in
          admin|write) row "ok" "peer:$peer" "access: $perm" ;;
          triage)      row "WARN" "peer:$peer" "access: triage — enough for issues, not for branches and pull requests" ;;
          *)           row "WARN" "peer:$peer" "access: $perm — triage or higher is needed for labels and closing" ;;
        esac
      else
        row "FAIL" "peer:$peer" "issues are disabled in this repository"; fail=$HF_EX_PRECOND
      fi ;;
    forbidden) row "FAIL" "peer:$peer" "403 — token lacks permissions (Issues/Contents/Pull requests: Read & Write) or SAML SSO authorisation"; fail=$HF_EX_PRECOND ;;
    notfound)  row "FAIL" "peer:$peer" "404 — repository missing or outside the token's reach"; fail=$HF_EX_PRECOND ;;
    *)         row "WARN" "peer:$peer" "could not be checked" ;;
  esac
done

# 6. API budget
rem=$(gh api rate_limit --jq .resources.core.remaining 2>/dev/null || echo '')
[ -n "$rem" ] && { [ "$rem" -lt 200 ] 2>/dev/null && row "WARN" "ratelimit" "$rem left" || row "ok" "ratelimit" "$rem left"; }

exit "$fail"
