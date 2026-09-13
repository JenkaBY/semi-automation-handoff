#!/usr/bin/env bash
# hf — the single CLI entry point of the handoff plugin.
#
#   hf <subcommand> [arguments]
#
# Output is deliberately compact (TSV / one line per record): these commands are
# called by an agent, and every extra line is spent tokens.

set -u

HF_SCRIPTS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
HF_PLUGIN_ROOT=${CLAUDE_PLUGIN_ROOT:-$(cd "$HF_SCRIPTS_DIR/.." && pwd)}
export HF_SCRIPTS_DIR HF_PLUGIN_ROOT

. "$HF_SCRIPTS_DIR/lib/log.sh"
. "$HF_SCRIPTS_DIR/lib/status.sh"
. "$HF_SCRIPTS_DIR/lib/gh.sh"
. "$HF_SCRIPTS_DIR/lib/config.sh"
. "$HF_SCRIPTS_DIR/lib/ref.sh"
. "$HF_SCRIPTS_DIR/lib/table.sh"
. "$HF_SCRIPTS_DIR/lib/retry.sh"
. "$HF_SCRIPTS_DIR/lib/meta.sh"

hf_usage() {
  cat <<'USAGE'
hf <subcommand> [arguments]

Environment and setup:
  doctor [--repo SLUG]              diagnostics: gh, token, permissions, labels, versions
  labels-ensure [--repo SLUG]       create the two service labels (idempotent)
  config-init [--repo SLUG] --peers "a b"
  version                           plugin and protocol versions

Orchestrator side:
  parent-ensure [--ref REF] --title T --body-file F
  comment-add --ref REF --body-file F [--kind result|question|note]
  routing-ensure --ref REF [--chain CHAIN]
  task-create --target SLUG --title T --body-file F --routing URL --context URL [--path P] [--labels a,b]
  routing-render --ref REF          rebuild the table from reactions on dependent tasks
  check [--ref REF] [--render]      summary of delegated tasks
  accept --ref REF [--force]        close the parent task once the chain is finished
  answer --ref REF --body-file F    the answer is appended to the same question comment

Assignee side:
  inbox [--all] [--repo SLUG]       incoming agent-task issues
  task-show --ref REF [--context]   the task plus links to its context
  status-set --ref REF --status CODE [--result-url URL] [--question-url URL]
  question-status --ref REF         has the question been answered yet

A task reference (REF) is accepted in any of these forms:
  42 | #42 | owner/repo#42 | https://github.com/owner/repo/issues/42 | ...#issuecomment-123 | -
USAGE
}

cmd=${1:-}
[ $# -gt 0 ] && shift

case "$cmd" in
  ''|-h|--help|help) hf_usage; exit 0 ;;
  version)
    hf_config_load
    printf 'plugin\t%s\nprotocol\t%s\n' "$(hf_plugin_version)" "${HANDOFF_PROTOCOL:-1}"
    exit 0 ;;
esac

script="$HF_SCRIPTS_DIR/cmd/${cmd}.sh"
[ -f "$script" ] || { hf_err "Unknown subcommand: $cmd"; hf_usage; exit "$HF_EX_CONFIG"; }
. "$script"
