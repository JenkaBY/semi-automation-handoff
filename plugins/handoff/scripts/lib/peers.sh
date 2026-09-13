#!/usr/bin/env bash
# lib/peers.sh — freshness bookkeeping for the map of neighbouring repositories.
#
# .handoff/external-repos.md is written for humans and agents, so the machine data
# lives beside it in .handoff/peers.lock — one line per repository:
#
#   owner/web<TAB>fingerprint<TAB>YYYY-MM-DD
#
# The fingerprint is a hash of the blob ids of the files the map is built from
# (README.md, AGENTS.md, CLAUDE.md, .handoff/config.env). It changes only when
# those files change, so a repository with unrelated commits is not re-surveyed.

hf_peers_lock_file() { printf '%s/peers.lock' "$(hf_config_dir)"; }

hf_peers_lock_get() {
  local f; f=$(hf_peers_lock_file)
  [ -f "$f" ] || return 1
  awk -F'\t' -v s="$1" '$1==s {print $2}' "$f" | tail -1
}

hf_peers_lock_date() {
  local f; f=$(hf_peers_lock_file)
  [ -f "$f" ] || return 1
  awk -F'\t' -v s="$1" '$1==s {print $3}' "$f" | tail -1
}

hf_peers_lock_set() {
  local slug="$1" fp="$2" f tmp
  f=$(hf_peers_lock_file)
  mkdir -p "$(dirname "$f")" 2>/dev/null || return 1
  tmp="$f.tmp.$$"
  if [ -f "$f" ]; then awk -F'\t' -v s="$slug" '$1!=s' "$f" > "$tmp"; else : > "$tmp"; fi
  printf '%s\t%s\t%s\n' "$slug" "$fp" "$(date -u +%Y-%m-%d)" >> "$tmp"
  sort -o "$tmp" "$tmp" 2>/dev/null || :
  mv -f "$tmp" "$f"
}

# Oldest refresh date across all recorded peers, in whole days. Empty if unknown.
hf_peers_lock_age_days() {
  local f oldest now then_s
  f=$(hf_peers_lock_file)
  [ -f "$f" ] || return 1
  oldest=$(awk -F'\t' '{print $3}' "$f" | sort | head -1)
  [ -n "$oldest" ] || return 1
  now=$(date -u +%s)
  then_s=$(hf_date_epoch "${oldest}T00:00:00Z") || return 1
  printf '%s' $(( (now - then_s) / 86400 ))
}

# hf_peers_probe <owner/repo>
# One GraphQL request per repository: blob ids of the map sources plus the
# neighbour's protocol version, without downloading README bodies.
# Prints TSV: fingerprint, protocol (or "-"), plugin-installed (yes|no)
hf_peers_probe() {
  local slug="$1" owner name out q jqt ids cfg proto installed
  owner=${slug%%/*}; name=${slug##*/}
  q='query($owner:String!,$name:String!){
    repository(owner:$owner,name:$name){
      readme: object(expression:"HEAD:README.md"){ oid }
      agents: object(expression:"HEAD:AGENTS.md"){ oid }
      claude: object(expression:"HEAD:CLAUDE.md"){ oid }
      cfg: object(expression:"HEAD:.handoff/config.env"){ oid ... on Blob { text } }
    }
  }'
  jqt='[ (.data.repository.readme.oid // "-"), (.data.repository.agents.oid // "-"), (.data.repository.claude.oid // "-"), (.data.repository.cfg.oid // "-"), ((.data.repository.cfg.text // "") | split("\n") | map(select(startswith("HANDOFF_PROTOCOL="))) | (first // "-")) ] | @tsv'
  out=$(gh api graphql -f query="$q" -F owner="$owner" -F name="$name" --jq "$jqt" 2>/dev/null) || return 1
  [ -n "$out" ] || return 1

  ids=$(printf '%s' "$out" | cut -f1-4 | tr '\t' ':')
  cfg=$(printf '%s' "$out" | cut -f4)
  proto=$(printf '%s' "$out" | cut -f5 | sed 's/^HANDOFF_PROTOCOL=//' | tr -d '"\r')
  [ -n "$proto" ] || proto="-"
  if [ "$cfg" = "-" ]; then installed="no"; else installed="yes"; fi
  printf '%s\t%s\t%s\n' "$(hf_sha8 "$ids")" "$proto" "$installed"
}
