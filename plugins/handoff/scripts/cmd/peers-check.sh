# hf peers-check [--repo SLUG] [--quiet]
# Tells which neighbours' descriptions are out of date, without re-surveying them.
# One GraphQL request per repository: only blob ids of README.md, AGENTS.md,
# CLAUDE.md and .handoff/config.env, never their contents.
#
# Output: slug<TAB>new|stale|fresh|unreachable<TAB>fingerprint<TAB>protocol<TAB>plugin
# Exit: 0 when everything is fresh, 1 when something needs a refresh.

only=""; quiet=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) only="$2"; shift 2 ;;
    --quiet) quiet=1; shift ;;
    *) hf_die "$HF_EX_CONFIG" "peers-check: unknown argument $1" ;;
  esac
done

hf_gh_require
hf_config_load --required

peers="${only:-${HANDOFF_PEERS:-}}"
[ -n "$peers" ] || hf_die "$HF_EX_CONFIG" \
  "HANDOFF_PEERS is empty — nothing to check. Run /handoff:init first."

needs=0
for slug in $peers; do
  if ! probe=$(hf_peers_probe "$slug"); then
    printf '%s\tunreachable\t-\t-\t-\n' "$slug"
    needs=1
    continue
  fi
  fp=$(printf '%s' "$probe" | cut -f1)
  proto=$(printf '%s' "$probe" | cut -f2)
  installed=$(printf '%s' "$probe" | cut -f3)

  if old=$(hf_peers_lock_get "$slug") && [ -n "$old" ]; then
    if [ "$old" = "$fp" ]; then status="fresh"; else status="stale"; needs=1; fi
  else
    status="new"; needs=1
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$slug" "$status" "$fp" "$proto" "$installed"

  if [ "$quiet" = 0 ]; then
    [ "$installed" = "no" ] && hf_warn "$slug: the handoff plugin is not installed there — its agent cannot pick tasks up."
    if [ "$proto" != "-" ] && ! hf_meta_check_protocol "$proto"; then
      hf_warn "$slug: protocol $proto, local ${HANDOFF_PROTOCOL:-1} — versions have drifted apart."
    fi
  fi
done

[ "$needs" -eq 0 ] || exit 1
exit 0
