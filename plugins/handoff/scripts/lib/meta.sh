#!/usr/bin/env bash
# lib/meta.sh — dependent task metadata: chain, idempotency key,
# delegation path (cycle protection), depth, versions.
#
# The block is visible to humans (collapsed <details>) and machine-readable.

hf_sha8() {
  if command -v sha1sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha1sum | cut -c1-8
  elif command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum | cut -c1-8
  else
    printf '%s' "$1" | cksum | awk '{printf "%08x", $1}'
  fi
}

hf_chain_new() {
  local rnd
  rnd=$(hf_sha8 "$$-$(date +%s)-${RANDOM:-0}")
  printf 'hf-%s-%s' "$(date -u +%Y%m%d)" "${rnd:0:4}"
}

# Idempotency key: one task per (chain, target repository) pair
hf_key() { hf_sha8 "$1|$2"; }

# --- Delegation path: owner/a>owner/b ----------------------------------------

hf_path_contains() {
  local path="$1" slug="$2"
  case ">$path>" in *">$slug>"*) return 0 ;; *) return 1 ;; esac
}

hf_path_append() {
  local path="$1" slug="$2"
  if [ -z "$path" ]; then printf '%s' "$slug"; else printf '%s>%s' "$path" "$slug"; fi
}

hf_path_depth() {
  local path="$1"
  [ -z "$path" ] && { printf '0'; return; }
  printf '%s' "$path" | awk -F'>' '{print NF}'
}

# --- Metadata block ----------------------------------------------------------

# hf_meta_block <chain> <key> <from> <context-url> <routing-url> <path> <depth> <protocol> <plugin>
hf_meta_block() {
  cat <<META
<details><summary>🔗 handoff meta</summary>

\`\`\`yaml
chain: $1
key: $2
from: $3
context: $4
routing: $5
path: $6
depth: $7
protocol: $8
plugin: $9
\`\`\`
</details>
META
}

# hf_meta_get <file> <key>
hf_meta_get() {
  sed -n "s/^${2}:[[:space:]]*//p" "$1" | head -1 | tr -d '\r'
}

# hf_meta_check_protocol <protocol-from-task> — major versions must match
hf_meta_check_protocol() {
  local remote="$1" local_p="${HANDOFF_PROTOCOL:-1}"
  [ -n "$remote" ] || return 0
  [ "${remote%%.*}" = "${local_p%%.*}" ]
}
