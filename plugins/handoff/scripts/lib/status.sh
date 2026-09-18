#!/usr/bin/env bash
# lib/status.sh — status model. A task's status is stored as a REACTION on the issue body;
# labels are never used for status.
#
# GitHub allows exactly eight reactions: +1 -1 laugh confused heart hooray rocket eyes.
# That is why DONE is 🚀: 💯 cannot be used as a reaction.

HF_STATUSES="NEW WIP BLOCKED DONE CANCELLED"

# Reaction the responder puts on a question comment to mark it answered
HF_REACTION_ANSWERED="+1"
HF_EMOJI_ANSWERED="👍"

hf_status_valid() {
  case " $HF_STATUSES " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

hf_status_emoji() {
  case "$1" in
    NEW)       printf '⬜' ;;
    WIP)       printf '👀' ;;
    BLOCKED)   printf '⛔' ;;
    DONE)      printf '🚀' ;;
    CANCELLED) printf '👎' ;;
    *)         printf '❔' ;;
  esac
}

# GitHub reaction for a status; NEW means "no status reactions"
hf_status_reaction() {
  case "$1" in
    WIP)       printf 'eyes' ;;
    BLOCKED)   printf 'confused' ;;
    DONE)      printf 'rocket' ;;
    CANCELLED) printf '-1' ;;
    *)         printf '' ;;
  esac
}

hf_status_from_reaction() {
  case "$1" in
    eyes)     printf 'WIP' ;;
    confused) printf 'BLOCKED' ;;
    rocket)   printf 'DONE' ;;
    -1)       printf 'CANCELLED' ;;
    *)        return 1 ;;
  esac
}

# Every reaction the plugin uses for status (so foreign statuses can be cleared)
HF_STATUS_REACTIONS="eyes confused rocket -1"

hf_is_status_reaction() {
  case " $HF_STATUS_REACTIONS " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

# hf_status_resolve "<space-separated reactions>" "<OPEN|CLOSED>"
# A closed issue counts as done: "a finished task is a closed task".
# Priority: CANCELLED > DONE > BLOCKED > WIP > NEW.
hf_status_resolve() {
  local reactions="$1" state="${2:-OPEN}"
  case " $reactions " in *" -1 "*) printf 'CANCELLED'; return 0 ;; esac
  case " $reactions " in *" rocket "*) printf 'DONE'; return 0 ;; esac
  if [ "$state" = "CLOSED" ]; then printf 'DONE'; return 0; fi
  case " $reactions " in *" confused "*) printf 'BLOCKED'; return 0 ;; esac
  case " $reactions " in *" eyes "*) printf 'WIP'; return 0 ;; esac
  printf 'NEW'
}

# GraphQL returns reaction names in upper case — map them to REST names
hf_reaction_from_graphql() {
  case "$1" in
    THUMBS_UP)   printf '+1' ;;
    THUMBS_DOWN) printf '-1' ;;
    EYES)        printf 'eyes' ;;
    CONFUSED)    printf 'confused' ;;
    ROCKET)      printf 'rocket' ;;
    HOORAY)      printf 'hooray' ;;
    HEART)       printf 'heart' ;;
    LAUGH)       printf 'laugh' ;;
    *)           printf '%s' "$1" | tr '[:upper:]' '[:lower:]' ;;
  esac
}

hf_status_desc() {
  case "$1" in
    NEW)       printf 'Created, not picked up yet' ;;
    WIP)       printf 'Picked up by the repository agent' ;;
    BLOCKED)   printf 'Waiting for a human answer' ;;
    DONE)      printf 'Finished and closed by the assignee' ;;
    CANCELLED) printf 'Cancelled' ;;
    *)         printf '' ;;
  esac
}

hf_status_legend() {
  printf '⬜ NEW · 👀 WIP · ⛔ BLOCKED · 🚀 DONE · 👎 CANCELLED'
}
