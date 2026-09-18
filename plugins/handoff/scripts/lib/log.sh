#!/usr/bin/env bash
# lib/log.sh — unified output and exit codes.
#
# handoff exit codes:
#   0  — success
#   2  — configuration/argument error, or a precondition of the command is unmet
#   3  — environment precondition failed (no gh, not authenticated, labels missing)
#   4  — graph violation (delegation cycle or depth exceeded)
#   5  — protocol version mismatch
#   6  — entity not found
#   7  — ambiguous state (question has 👍 but no answer) → stop and ask a human
#   75 — conflict unresolved after N attempts (EX_TEMPFAIL) → mark BLOCKED, ask a human

HF_EX_OK=0
HF_EX_CONFIG=2
HF_EX_PRECOND=3
HF_EX_GRAPH=4
HF_EX_PROTOCOL=5
HF_EX_NOTFOUND=6
HF_EX_AMBIGUOUS=7
HF_EX_CONFLICT=75

if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
  HF_C_RED=$'\033[31m'; HF_C_YEL=$'\033[33m'; HF_C_GRN=$'\033[32m'
  HF_C_DIM=$'\033[2m'; HF_C_OFF=$'\033[0m'
else
  HF_C_RED=''; HF_C_YEL=''; HF_C_GRN=''; HF_C_DIM=''; HF_C_OFF=''
fi

hf_log()  { printf '%s\n' "$*"; }
hf_note() { printf '%s%s%s\n' "$HF_C_DIM" "$*" "$HF_C_OFF" >&2; }
hf_ok()   { printf '%s✔%s %s\n' "$HF_C_GRN" "$HF_C_OFF" "$*" >&2; }
hf_warn() { printf '%s⚠%s %s\n' "$HF_C_YEL" "$HF_C_OFF" "$*" >&2; }
hf_err()  { printf '%s✖%s %s\n' "$HF_C_RED" "$HF_C_OFF" "$*" >&2; }

# hf_die <code> <message...>
hf_die() {
  local code="$1"; shift
  hf_err "$*"
  exit "$code"
}

hf_debug() { [ -n "${HF_DEBUG:-}" ] && printf '%s· %s%s\n' "$HF_C_DIM" "$*" "$HF_C_OFF" >&2; return 0; }
