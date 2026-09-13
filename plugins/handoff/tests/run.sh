#!/usr/bin/env bash
# Offline test suite: no network, gh is shadowed by tests/mock.
# It covers what cannot be eyeballed: row merging, optimistic locking, exhausted
# retries, cycle protection, idempotency, reaction-based statuses and the
# "question and answer live in one comment" protocol.
set -u
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PLUGIN=$(cd "$HERE/.." && pwd)
HF="$PLUGIN/scripts/hf.sh"

pass=0; fail=0
ok()   { pass=$((pass+1)); printf '  ✔ %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf '  ✖ %s\n     %s\n' "$1" "${2:-}"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected «$3», got «$2»"; fi; }

setup() {
  SANDBOX=$(mktemp -d)
  export HF_MOCK_DIR="$SANDBOX/mock" HANDOFF_ROOT="$SANDBOX/repo" HF_MOCK_REPO="owner/api"
  export HF_NO_SLEEP=1 HF_RETRY_MAX=3
  export PATH="$HERE/mock:$PATH"
  unset HF_MOCK_INTERFERE HF_MOCK_INTERFERE_ALWAYS HF_MOCK_PR HF_REPO_CACHE || :
  mkdir -p "$HANDOFF_ROOT/.handoff" "$HF_MOCK_DIR"
  cat > "$HANDOFF_ROOT/.handoff/config.env" <<CFG
HANDOFF_PROTOCOL=1
HANDOFF_REPO=owner/api
HANDOFF_PEERS="owner/web owner/infra"
HANDOFF_MAX_DEPTH=3
CFG
}
teardown() { rm -rf "$SANDBOX"; }

make_parent() {
  printf 'parent task\n' > "$SANDBOX/pbody"
  local out num
  out=$(bash "$HF" parent-ensure --title "Test" --body-file "$SANDBOX/pbody" 2>/dev/null)
  num=$(printf '%s' "$out" | cut -f2)
  bash "$HF" routing-ensure --ref "$num" 2>/dev/null | cut -f4
}

make_task() {   # prints owner/web#N
  printf 'do X\n' > "$SANDBOX/tbody"
  bash "$HF" task-create --target owner/web --title T --body-file "$SANDBOX/tbody" \
    --routing "$1" --context "ctx" 2>/dev/null | cut -f2
}

echo "== lib: task reference parsing =="
setup
(
  . "$PLUGIN/scripts/lib/log.sh"; . "$PLUGIN/scripts/lib/status.sh"
  . "$PLUGIN/scripts/lib/gh.sh"; . "$PLUGIN/scripts/lib/config.sh"; . "$PLUGIN/scripts/lib/ref.sh"
  hf_config_load >/dev/null 2>&1
  t() { if hf_resolve_ref "$1"; then printf '%s|%s|%s' "$HF_REF_REPO" "$HF_REF_NUM" "$HF_REF_COMMENT"; else printf 'ERR'; fi; }
  printf '%s\n' "$(t 42)" "$(t '#42')" "$(t 'owner/web#7')" \
    "$(t 'https://github.com/owner/web/issues/7')" \
    "$(t 'https://github.com/owner/api/issues/42#issuecomment-555')" "$(t 'garbage')"
) > "$SANDBOX/refs.txt"
check "plain number"      "$(sed -n 1p "$SANDBOX/refs.txt")" "owner/api|42|"
check "#number"           "$(sed -n 2p "$SANDBOX/refs.txt")" "owner/api|42|"
check "slug#number"       "$(sed -n 3p "$SANDBOX/refs.txt")" "owner/web|7|"
check "issue URL"         "$(sed -n 4p "$SANDBOX/refs.txt")" "owner/web|7|"
check "comment URL"       "$(sed -n 5p "$SANDBOX/refs.txt")" "owner/api|42|555"
check "garbage rejected"  "$(sed -n 6p "$SANDBOX/refs.txt")" "ERR"
teardown

echo "== lib: statuses resolved from reactions =="
setup
(
  . "$PLUGIN/scripts/lib/log.sh"; . "$PLUGIN/scripts/lib/status.sh"
  printf '%s\n' "$(hf_status_resolve 'eyes' OPEN)" "$(hf_status_resolve 'eyes confused' OPEN)" \
    "$(hf_status_resolve '' CLOSED)" "$(hf_status_resolve 'rocket' OPEN)" \
    "$(hf_status_resolve '-1 rocket' CLOSED)" "$(hf_status_resolve '' OPEN)"
) > "$SANDBOX/st.txt"
check "👀 → WIP"              "$(sed -n 1p "$SANDBOX/st.txt")" "WIP"
check "👀+😕 → BLOCKED"       "$(sed -n 2p "$SANDBOX/st.txt")" "BLOCKED"
check "closed → DONE"         "$(sed -n 3p "$SANDBOX/st.txt")" "DONE"
check "🚀 → DONE"             "$(sed -n 4p "$SANDBOX/st.txt")" "DONE"
check "👎 outranks 🚀"        "$(sed -n 5p "$SANDBOX/st.txt")" "CANCELLED"
check "no reactions → NEW"    "$(sed -n 6p "$SANDBOX/st.txt")" "NEW"
teardown

echo "== lib: row merging in the routing table =="
setup
(
  . "$PLUGIN/scripts/lib/log.sh"; . "$PLUGIN/scripts/lib/status.sh"; . "$PLUGIN/scripts/lib/table.sh"
  hf_table_body_new "hf-test" > "$SANDBOX/t0"
  hf_table_set_row "$SANDBOX/t0" "owner/web" "[#1](u1)" "NEW" "" "" > "$SANDBOX/t1"
  hf_table_set_row "$SANDBOX/t1" "owner/infra" "[#2](u2)" "WIP" "" "[question](q)" > "$SANDBOX/t2"
  hf_table_set_row "$SANDBOX/t2" "owner/web" "[#1](u1)" "DONE" "[r](u3)" "" > "$SANDBOX/t3"
)
check "foreign row untouched"    "$(grep -c 'owner/infra' "$SANDBOX/t3")" "1"
check "neighbour question kept"  "$(grep 'owner/infra' "$SANDBOX/t3" | grep -c 'question')" "1"
check "own row updated"          "$(grep 'owner/web' "$SANDBOX/t3" | grep -c 'DONE')" "1"
check "exactly two rows"         "$(grep -c '^| `' "$SANDBOX/t3")" "2"
check "six columns"              "$(grep 'owner/web' "$SANDBOX/t3" | tr -cd '|' | wc -c | tr -d ' ')" "7"
teardown

echo "== routing-set: happy path and concurrency =="
setup
ROUT=$(make_parent); cid=${ROUT##*-}
out=$(bash "$HF" routing-set --routing "$ROUT" --slug owner/web --status WIP --task '[#5](u5)' 2>/dev/null)
check "status written" "$(printf '%s' "$out" | cut -f4)" "ok"
check "row in the body" "$(grep -c 'owner/web' "$HF_MOCK_DIR/comments/$cid.body")" "1"
teardown

setup
ROUT=$(make_parent); cid=${ROUT##*-}
export HF_MOCK_INTERFERE=1
out=$(bash "$HF" routing-set --routing "$ROUT" --slug owner/web --status WIP --task '[#5](u5)' 2>/dev/null)
check "one interfering write: ok"  "$(printf '%s' "$out" | cut -f4)" "ok"
check "foreign row preserved"      "$(grep -c 'zzz/other' "$HF_MOCK_DIR/comments/$cid.body")" "1"
check "our row is there"           "$(grep -c 'owner/web' "$HF_MOCK_DIR/comments/$cid.body")" "1"
teardown

setup
ROUT=$(make_parent)
export HF_MOCK_INTERFERE_ALWAYS=1
bash "$HF" routing-set --routing "$ROUT" --slug owner/web --status WIP --task '[#5](u5)' >/dev/null 2>&1
check "constant conflict → 75" "$?" "75"
teardown

echo "== task-create: cycle, depth, foreign repository, idempotency =="
setup
ROUT=$(make_parent)
printf 'do X\n' > "$SANDBOX/tbody"
bash "$HF" task-create --target owner/web --title T --body-file "$SANDBOX/tbody" \
  --routing "$ROUT" --context ctx --path "owner/api>owner/web" >/dev/null 2>&1
check "cycle rejected (exit 4)" "$?" "4"
bash "$HF" task-create --target owner/web --title T --body-file "$SANDBOX/tbody" \
  --routing "$ROUT" --context ctx --path "a/1>b/2>c/3" >/dev/null 2>&1
check "depth rejected (exit 4)" "$?" "4"
bash "$HF" task-create --target stranger/repo --title T --body-file "$SANDBOX/tbody" \
  --routing "$ROUT" --context ctx >/dev/null 2>&1
check "non-peer rejected (exit 2)" "$?" "2"
out1=$(bash "$HF" task-create --target owner/web --title T --body-file "$SANDBOX/tbody" \
        --routing "$ROUT" --context ctx 2>/dev/null)
out2=$(bash "$HF" task-create --target owner/web --title T --body-file "$SANDBOX/tbody" \
        --routing "$ROUT" --context ctx 2>/dev/null)
check "first one created"   "$(printf '%s' "$out1" | cut -f4)" "created"
check "second one reused"   "$(printf '%s' "$out2" | cut -f4)" "reused"
check "same issue number"   "$(printf '%s' "$out2" | cut -f2)" "$(printf '%s' "$out1" | cut -f2)"
n=${out1#*#}; n=$(printf '%s' "$n" | cut -f1)
check "agent-task is the only label" "$(grep -c . "$HF_MOCK_DIR/issues/owner_web/$n.labels")" "1"
teardown

echo "== status-set: reactions, closing on DONE, protocol guard =="
setup
ROUT=$(make_parent); cid=${ROUT##*-}
T=$(make_task "$ROUT"); NUM=${T##*#}
out=$(bash "$HF" status-set --ref "$T" --status WIP 2>/dev/null)
check "routing updated"      "$(printf '%s' "$out" | cut -f4)" "routing:ok"
check "eyes reaction"        "$(grep -c ' eyes$' "$HF_MOCK_DIR/issues/owner_web/$NUM.reactions")" "1"
check "table says WIP"       "$(grep 'owner/web' "$HF_MOCK_DIR/comments/$cid.body" | grep -c 'WIP')" "1"
check "issue still open"     "$(cat "$HF_MOCK_DIR/issues/owner_web/$NUM.state")" "OPEN"
bash "$HF" status-set --ref "$T" --status DONE --result-url "https://x/y#issuecomment-9" >/dev/null 2>&1
check "rocket reaction"      "$(grep -c ' rocket$' "$HF_MOCK_DIR/issues/owner_web/$NUM.reactions")" "1"
check "DONE closes the task" "$(cat "$HF_MOCK_DIR/issues/owner_web/$NUM.state")" "CLOSED"
check "result link in table" "$(grep 'owner/web' "$HF_MOCK_DIR/comments/$cid.body" | grep -c 'result')" "1"
sed 's/^protocol: 1$/protocol: 2/' "$HF_MOCK_DIR/issues/owner_web/$NUM.body" > "$SANDBOX/b2" && \
  mv "$SANDBOX/b2" "$HF_MOCK_DIR/issues/owner_web/$NUM.body"
bash "$HF" status-set --ref "$T" --status DONE >/dev/null 2>&1
check "foreign protocol → exit 5" "$?" "5"
teardown

echo "== question and answer live in one comment =="
setup
ROUT=$(make_parent); cid=${ROUT##*-}
T=$(make_task "$ROUT"); NUM=${T##*#}
printf 'which date format?\n' > "$SANDBOX/q"
Q=$(bash "$HF" comment-add --ref "$T" --body-file "$SANDBOX/q" --kind question 2>/dev/null | cut -f3)
qid=${Q##*-}
bash "$HF" status-set --ref "$T" --status BLOCKED --question-url "$Q" >/dev/null 2>&1
check "confused reaction"    "$(grep -c ' confused$' "$HF_MOCK_DIR/issues/owner_web/$NUM.reactions")" "1"
check "question in table"    "$(grep 'owner/web' "$HF_MOCK_DIR/comments/$cid.body" | grep -c 'question')" "1"

out=$(bash "$HF" question-status --ref "$Q" 2>/dev/null)
check "question is pending"  "$(printf '%s' "$out" | head -1 | cut -f3)" "pending"

before=$(wc -l < "$HF_MOCK_DIR/comment_index")
printf 'ISO-8601 in UTC\n' > "$SANDBOX/a"
bash "$HF" answer --ref "$Q" --body-file "$SANDBOX/a" >/dev/null 2>&1
after=$(wc -l < "$HF_MOCK_DIR/comment_index")
check "no new comment created"     "$after" "$before"
check "answer in the same comment" "$(grep -c 'ISO-8601' "$HF_MOCK_DIR/comments/$qid.body")" "1"
check "question still in it"       "$(grep -c 'which date format' "$HF_MOCK_DIR/comments/$qid.body")" "1"
check "👍 on the question"         "$(grep -c '^+1$' "$HF_MOCK_DIR/comments/$qid.reactions")" "1"
check "block lifted"               "$(bash "$HF" task-show --ref "$T" --no-body 2>/dev/null | sed -n 's/^STATUS\t//p' | awk '{print $2}')" "NEW"

out=$(bash "$HF" question-status --ref "$Q" 2>/dev/null)
check "question answered"    "$(printf '%s' "$out" | head -1 | cut -f3)" "answered"
check "answer text returned" "$(printf '%s' "$out" | grep -c 'ISO-8601')" "1"

# the assignee read the answer and clears the question link from its own row
bash "$HF" status-set --ref "$T" --status WIP --clear-question >/dev/null 2>&1
check "question link cleared" "$(grep 'owner/web' "$HF_MOCK_DIR/comments/$cid.body" | grep -c 'question')" "0"
teardown

echo "== 👍 present but no answer — stop (exit 7) =="
setup
ROUT=$(make_parent)
T=$(make_task "$ROUT")
printf 'unanswered question\n' > "$SANDBOX/q"
Q=$(bash "$HF" comment-add --ref "$T" --body-file "$SANDBOX/q" --kind question 2>/dev/null | cut -f3)
qid=${Q##*-}
printf '+1\n' > "$HF_MOCK_DIR/comments/$qid.reactions"
bash "$HF" question-status --ref "$Q" >/dev/null 2>&1
check "reaction without answer → exit 7" "$?" "7"
teardown

echo "== accept: closes the parent only when everything is finished =="
setup
ROUT=$(make_parent)
P=$(bash "$HF" parent-ensure --ref 1 2>/dev/null | cut -f2)
T=$(make_task "$ROUT"); NUM=${T##*#}
bash "$HF" status-set --ref "$T" --status WIP >/dev/null 2>&1
out=$(bash "$HF" accept --ref "$P" 2>/dev/null); rc=$?
check "unfinished → refused"    "$(printf '%s' "$out" | tail -1 | cut -f3)" "pending"
check "refusal exit code 2"     "$rc" "2"
check "parent stays open"       "$(cat "$HF_MOCK_DIR/issues/owner_api/1.state")" "OPEN"
bash "$HF" status-set --ref "$T" --status BLOCKED >/dev/null 2>&1
out=$(bash "$HF" accept --ref "$P" 2>/dev/null)
check "blocked → refused"       "$(printf '%s' "$out" | tail -1 | cut -f3)" "blocked"
bash "$HF" status-set --ref "$T" --status DONE >/dev/null 2>&1
out=$(bash "$HF" accept --ref "$P" 2>/dev/null)
check "all finished → closed"   "$(printf '%s' "$out" | tail -1 | cut -f3)" "closed"
check "parent is closed"        "$(cat "$HF_MOCK_DIR/issues/owner_api/1.state")" "CLOSED"
teardown

echo "== inbox: status comes from reactions =="
setup
ROUT=$(make_parent)
T=$(make_task "$ROUT")
export HF_MOCK_REPO="owner/web"
out=$(bash "$HF" inbox --repo owner/web 2>/dev/null)
check "task is listed"       "$(printf '%s' "$out" | grep -c '^#')" "1"
check "status NEW"           "$(printf '%s' "$out" | head -1 | cut -f2 | awk '{print $2}')" "NEW"
bash "$HF" status-set --ref "$T" --status WIP >/dev/null 2>&1
out=$(bash "$HF" inbox --repo owner/web 2>/dev/null)
check "status became WIP"    "$(printf '%s' "$out" | head -1 | cut -f2 | awk '{print $2}')" "WIP"
check "origin is visible"    "$(printf '%s' "$out" | head -1 | cut -f4)" "owner/api#1"
bash "$HF" status-set --ref "$T" --status DONE >/dev/null 2>&1
out=$(bash "$HF" inbox --repo owner/web --all 2>/dev/null)
check "closed task → DONE"   "$(printf '%s' "$out" | head -1 | cut -f2 | awk '{print $2}')" "DONE"
check "columns did not shift" "$(printf '%s' "$out" | head -1 | cut -f5)" "T"
teardown

echo "== peers-check: only re-survey what actually changed =="
setup
mkdir -p "$HF_MOCK_DIR/peers"
printf 'readme-v1' > "$HF_MOCK_DIR/peers/owner_web.src"
printf '1' > "$HF_MOCK_DIR/peers/owner_web.proto"
printf 'readme-v1' > "$HF_MOCK_DIR/peers/owner_infra.src"
out=$(bash "$HF" peers-check --repo owner/web 2>/dev/null); rc=$?
check "unknown peer → new"        "$(printf '%s' "$out" | cut -f2)" "new"
check "needs refresh → exit 1"    "$rc" "1"
fp=$(printf '%s' "$out" | cut -f3)
bash "$HF" peers-stamp --repo owner/web --fingerprint "$fp" >/dev/null 2>&1
out=$(bash "$HF" peers-check --repo owner/web 2>/dev/null); rc=$?
check "after stamping → fresh"    "$(printf '%s' "$out" | cut -f2)" "fresh"
check "nothing to do → exit 0"    "$rc" "0"
printf 'readme-v2' > "$HF_MOCK_DIR/peers/owner_web.src"
out=$(bash "$HF" peers-check --repo owner/web 2>/dev/null); rc=$?
check "sources changed → stale"   "$(printf '%s' "$out" | cut -f2)" "stale"
check "stale → exit 1"            "$rc" "1"
out=$(bash "$HF" peers-check --repo owner/infra 2>/dev/null)
check "no config.env → plugin no" "$(printf '%s' "$out" | cut -f5)" "no"
out=$(bash "$HF" peers-check --repo owner/gone 2>/dev/null); rc=$?
check "missing repo → unreachable" "$(printf '%s' "$out" | cut -f2)" "unreachable"
check "lock records the date"     "$(cut -f3 "$HANDOFF_ROOT/.handoff/peers.lock")" "$(date -u +%Y-%m-%d)"
teardown

echo
printf 'Total: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
