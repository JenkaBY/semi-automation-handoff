# hf peers-stamp --repo SLUG [--fingerprint FP]
# Records that this neighbour's description in .handoff/external-repos.md now matches
# its sources. Call it right after rewriting that repository's section — never before,
# or a failed refresh would look finished.
# Output: peers-stamp<TAB>slug<TAB>fingerprint<TAB>date

slug=""; fp=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) slug="$2"; shift 2 ;;
    --fingerprint) fp="$2"; shift 2 ;;
    *) hf_die "$HF_EX_CONFIG" "peers-stamp: unknown argument $1" ;;
  esac
done

hf_config_load --required
[ -n "$slug" ] || hf_die "$HF_EX_CONFIG" "peers-stamp: --repo owner/name required"

if [ -z "$fp" ]; then
  hf_gh_require
  probe=$(hf_peers_probe "$slug") || hf_die "$HF_EX_NOTFOUND" "peers-stamp: cannot read $slug"
  fp=$(printf '%s' "$probe" | cut -f1)
fi

hf_peers_lock_set "$slug" "$fp" || hf_die "$HF_EX_PRECOND" "peers-stamp: cannot write $(hf_peers_lock_file)"
printf 'peers-stamp\t%s\t%s\t%s\n' "$slug" "$fp" "$(date -u +%Y-%m-%d)"
exit 0
