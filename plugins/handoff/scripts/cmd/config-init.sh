# hf config-init [--repo SLUG] --peers "owner/a owner/b" [--max-depth N] [--stale-days N]
# Writes .handoff/config.env, extends .gitignore and creates .claude/settings.json
# if it does not exist yet. An existing settings.json is NOT touched — the snippet
# is printed instead for a manual merge (splicing JSON without jq is unsafe).
# Output: config<TAB>path<TAB>written|updated, plus MERGE-SETTINGS when needed

repo=""; peers=""; maxd=""; stale=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;
    --peers) peers="$2"; shift 2 ;;
    --max-depth) maxd="$2"; shift 2 ;;
    --stale-days) stale="$2"; shift 2 ;;
    *) hf_die "$HF_EX_CONFIG" "config-init: unknown argument $1" ;;
  esac
done

hf_config_load
root=$(hf_repo_root)
dir="$root/.handoff"
file="$dir/config.env"
[ -n "$repo" ] || repo=${HANDOFF_REPO:-$(hf_gh_current_repo 2>/dev/null || true)}
[ -n "$repo" ] || hf_die "$HF_EX_CONFIG" "config-init: repository unknown, pass --repo owner/name"

mode="written"; [ -f "$file" ] && mode="updated"
mkdir -p "$dir"
cat > "$file" <<CFG
# handoff plugin configuration. Commit this file.
# Flat KEY=VALUE so that both bash scripts and humans can read it.
HANDOFF_PROTOCOL=${HANDOFF_PROTOCOL:-1}
HANDOFF_REPO=$repo
HANDOFF_PEERS="${peers:-${HANDOFF_PEERS:-}}"
HANDOFF_MAX_DEPTH=${maxd:-${HANDOFF_MAX_DEPTH:-3}}
HANDOFF_STALE_DAYS=${stale:-${HANDOFF_STALE_DAYS:-3}}
HANDOFF_LABEL_TASK=${HANDOFF_LABEL_TASK:-agent-task}
HANDOFF_LABEL_PREFIX=${HANDOFF_LABEL_PREFIX:-handoff:}
HANDOFF_LABEL_PARENT=${HANDOFF_LABEL_PARENT:-handoff:parent}
CFG
printf 'config\t%s\t%s\n' "$file" "$mode"

gi="$root/.gitignore"
if ! { [ -f "$gi" ] && grep -Fq '.handoff/state.env' "$gi"; }; then
  printf '\n# handoff: local session state, not for committing\n.handoff/state.env\n' >> "$gi"
  printf 'gitignore\t%s\tupdated\n' "$gi"
fi

settings="$root/.claude/settings.json"
snippet='{
  "extraKnownMarketplaces": {
    "handoff-marketplace": {
      "source": { "source": "github", "repo": "jenkaBY/semi-automation-handoff" }
    }
  },
  "enabledPlugins": { "handoff@handoff-marketplace": true }
}'
if [ -f "$settings" ]; then
  if grep -q 'handoff@handoff-marketplace' "$settings"; then
    printf 'settings\t%s\talready-configured\n' "$settings"
  else
    printf 'settings\t%s\tMERGE-REQUIRED\n' "$settings"
    printf 'MERGE-SETTINGS\n%s\n' "$snippet"
  fi
else
  mkdir -p "$root/.claude"
  printf '%s\n' "$snippet" > "$settings"
  printf 'settings\t%s\twritten\n' "$settings"
fi
exit 0
