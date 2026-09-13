#!/usr/bin/env bash
# lib/config.sh — repository root discovery, .handoff/config.env and state.env.
# The machine-readable config is flat KEY=VALUE so that no jq is required
# (it is not installed by default on Windows).

HF_CONFIG_DIR_NAME=".handoff"

# Repository root: HANDOFF_ROOT (tests) → git → current directory
hf_repo_root() {
  if [ -n "${HANDOFF_ROOT:-}" ]; then printf '%s' "$HANDOFF_ROOT"; return 0; fi
  local root
  if root=$(git rev-parse --show-toplevel 2>/dev/null) && [ -n "$root" ]; then
    printf '%s' "$root"; return 0
  fi
  printf '%s' "$PWD"
}

hf_config_dir()  { printf '%s/%s' "$(hf_repo_root)" "$HF_CONFIG_DIR_NAME"; }
hf_config_file() { printf '%s/config.env' "$(hf_config_dir)"; }
hf_state_file()  { printf '%s/state.env' "$(hf_config_dir)"; }

# Safe KEY=VALUE reader: the file is never executed, only lines shaped like
# HANDOFF_<NAME>=<value> are taken.
hf_load_env_file() {
  local file="$1" line key val
  [ -f "$file" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      HANDOFF_[A-Z0-9_]*=*) ;;
      *) continue ;;
    esac
    key=${line%%=*}
    val=${line#*=}
    val=${val%%$'\r'}
    case "$val" in
      \"*\") val=${val#\"}; val=${val%\"} ;;
      \'*\') val=${val#\'}; val=${val%\'} ;;
    esac
    eval "$key=\$val; export $key"
  done < "$file"
  return 0
}

hf_config_defaults() {
  : "${HANDOFF_PROTOCOL:=1}"
  : "${HANDOFF_MAX_DEPTH:=3}"
  : "${HANDOFF_LABEL_TASK:=agent-task}"
  : "${HANDOFF_LABEL_PREFIX:=handoff:}"
  : "${HANDOFF_LABEL_PARENT:=handoff:parent}"
  : "${HANDOFF_STALE_DAYS:=3}"
  : "${HANDOFF_PEERS:=}"
  export HANDOFF_PROTOCOL HANDOFF_MAX_DEPTH HANDOFF_LABEL_TASK HANDOFF_LABEL_PREFIX \
         HANDOFF_LABEL_PARENT HANDOFF_STALE_DAYS HANDOFF_PEERS
}

# hf_config_load [--required]
hf_config_load() {
  local required="${1:-}"
  HF_CONFIG_FOUND=0
  if hf_load_env_file "$(hf_config_file)"; then
    HF_CONFIG_FOUND=1
  elif [ "$required" = "--required" ]; then
    hf_die "$HF_EX_CONFIG" "$(hf_config_file) not found. Run /handoff:init in this repository."
  fi
  hf_config_defaults
  if [ -z "${HANDOFF_REPO:-}" ]; then
    HANDOFF_REPO=$(hf_gh_current_repo 2>/dev/null || true)
    export HANDOFF_REPO
  fi
  return 0
}

hf_is_peer() {
  local slug="$1"
  [ "$slug" = "${HANDOFF_REPO:-}" ] && return 0
  case " ${HANDOFF_PEERS:-} " in *" $slug "*) return 0 ;; *) return 1 ;; esac
}

# Plugin version from .claude-plugin/plugin.json (without jq)
hf_plugin_version() {
  local manifest="${HF_PLUGIN_ROOT:-}/.claude-plugin/plugin.json"
  if [ -f "$manifest" ]; then
    sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$manifest" | head -1
  else
    printf 'unknown'
  fi
}

# --- state.env: "the task this session is working on" ------------------------

hf_state_get() {
  local key="$1" file
  file=$(hf_state_file)
  [ -f "$file" ] || return 1
  sed -n "s/^${key}=//p" "$file" | tail -1
}

hf_state_set() {
  local key="$1" val="$2" file tmp
  file=$(hf_state_file)
  mkdir -p "$(dirname "$file")" 2>/dev/null || return 0
  tmp="${file}.tmp.$$"
  if [ -f "$file" ]; then grep -v "^${key}=" "$file" > "$tmp" 2>/dev/null || : ; else : > "$tmp"; fi
  printf '%s=%s\n' "$key" "$val" >> "$tmp"
  mv -f "$tmp" "$file" 2>/dev/null || rm -f "$tmp"
  return 0
}
