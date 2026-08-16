#!/usr/bin/env bash
# evals/ledger/doc_read_cases.sh — §4 cases for audits/doc-read.sh.
#
# Sourced by run.sh, never executed. Split off when the runner reached 345 of
# the 350-line cap: the read-record cases are a self-contained concern (they
# need a real git repository per case, which the census cases do not), so they
# read better as their own list.

# --- §4 doc-read record ------------------------------------------------------


# Dimension 4.1 — append-only, one row per call. Two sessions writing at once
# stay legible because no call ever rewrites what another wrote.
sb="$(mk_repo)"
run_doc_read "$sb" log "dispatch/write_fixture.md" >/dev/null
run_doc_read "$sb" log "docs/LOGGING_STANDARD.md" >/dev/null
run_doc_read "$sb" log "/etc/hosts" >/dev/null
rows="$(wc -l < "$(repo_log "$sb")" | tr -d ' ')"
shaped="$(grep -cE '^\{"ts":[0-9]+,"path":"[^"]+","blob":"[0-9a-f]+"\}$' "$(repo_log "$sb")")"
if [ "$rows" -eq 2 ] && [ "$shaped" -eq 2 ]; then
  ok "ledger_readlog_append — 2 well-formed rows, the out-of-tree path dropped"
else
  bad "ledger_readlog_append" "rows=$rows well-formed=$shaped (want 2 and 2)"
fi

# Dimension 4.2 — the matrix. No record cannot red: an agent runtime without
# hook support would otherwise fail every commit for a mechanism it never had.
sb="$(mk_repo)"
printf '#!/bin/sh\necho hi\n' > "$sb/tool.sh"
git -C "$sb" add tool.sh >/dev/null 2>&1
out_absent="$(run_doc_read "$sb" check)"; absent_rc=$?
run_doc_read "$sb" log "docs/CHANGELOG_VOICE.md" >/dev/null
out_missing="$(run_doc_read "$sb" check)"; missing_rc=$?
run_doc_read "$sb" log "dispatch/write_fixture.md" >/dev/null
out_read="$(run_doc_read "$sb" check)"; read_rc=$?
if [ "$absent_rc" -eq 0 ] && printf '%s' "$out_absent" | grep -q '🟠' \
   && [ "$missing_rc" -eq 1 ] && printf '%s' "$out_missing" | grep -q 'dispatch/write_fixture.md' \
   && [ "$read_rc" -eq 0 ] && printf '%s' "$out_read" | grep -q '🟢'; then
  ok "ledger_readlog_check_matrix — no record 0 🟠, unread 1 naming the façade, read 0 🟢"
else
  bad "ledger_readlog_check_matrix" "absent=$absent_rc missing=$missing_rc read=$read_rc"
fi

# Dimension 4.2b — a staged diff that triggers nothing is green without a
# record at all: the check reports on triggers, not on reading habits.
sb="$(mk_repo)"
printf 'notes\n' > "$sb/NOTES.txt"
git -C "$sb" add NOTES.txt >/dev/null 2>&1
out="$(run_doc_read "$sb" check)"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'nothing staged triggers'; then
  ok "ledger_readlog_untriggered — a prose-only diff needs no read"
else
  bad "ledger_readlog_untriggered" "exit=$rc out: $out"
fi

# Dimension 4.2c — validity is keyed to content, not to a clock. Reading a
# façade and then editing it must void the read: the agent saw a different
# document. A timestamp window silently passes this case, which is why it was
# replaced.
sb="$(mk_repo)"
printf '#!/bin/sh\necho hi\n' > "$sb/tool.sh"
git -C "$sb" add tool.sh >/dev/null 2>&1
run_doc_read "$sb" log "dispatch/write_fixture.md" >/dev/null
run_doc_read "$sb" check >/dev/null; before_rc=$?
printf '\nA new rule the agent has never seen.\n' >> "$sb/dispatch/write_fixture.md"
out_after="$(run_doc_read "$sb" check)"; after_rc=$?
run_doc_read "$sb" log "dispatch/write_fixture.md" >/dev/null
run_doc_read "$sb" check >/dev/null; reread_rc=$?
if [ "$before_rc" -eq 0 ] && [ "$after_rc" -eq 1 ] && [ "$reread_rc" -eq 0 ] \
   && printf '%s' "$out_after" | grep -q 'current content'; then
  ok "ledger_readlog_content_keyed — editing the façade voids the read; re-reading restores it"
else
  bad "ledger_readlog_content_keyed" "before=$before_rc edited=$after_rc reread=$reread_rc"
fi

# Dimension 4.3 — the wiring itself. A check nothing invokes is a check nobody
# runs, so the hook's guarded call is part of the deliverable.
hook="$ROOT/.githooks/pre-commit"
if grep -q 'audits/doc-read.sh check' "$hook" \
   && grep -q 'SOURCE_PATTERN' "$hook" \
   && grep -q 'diff --cached --name-only' "$hook"; then
  ok "ledger_precommit_wiring — pre-commit calls check behind a staged-source guard"
else
  bad "ledger_precommit_wiring" "no guarded doc-read.sh invocation in .githooks/pre-commit"
fi

# Dimension 5.1 — the pilot. LOGGING_STANDARD is the doc whose 2-of-34 ratio
# motivated the milestone; every clause in it now carries a class, so the
# scoreboard reports a real ratio instead of a backlog.
row="$(ORLY_ROOT="$ROOT" bash "$LEDGER" --census 2>&1 | grep 'LOGGING_STANDARD')"
if printf '%s' "$row" | grep -q 'untagged=0' && ! printf '%s' "$row" | grep -q 'det=0 '; then
  ok "ledger_pilot_fully_classified — LOGGING_STANDARD untagged=0 with a non-zero deterministic count"
else
  bad "ledger_pilot_fully_classified" "row: $row"
fi

# Dimension 5.1b — the grammar the pilot uses is the grammar the dispatch tier
# already writes. If a block tag under a heading stopped covering its section,
# the façade pages would silently read as untagged too.
counts="$(bash -c 'source "'"$ROOT"'/audits/rule-ledger-lib.sh"; ledger_doc_counts "'"$ROOT"'/dispatch/write_any.md"')"
det_block="$(printf '%s' "$counts" | cut -d' ' -f2)"
if [ -n "$det_block" ] && [ "$det_block" -gt 0 ]; then
  ok "ledger_block_tag_scope — dispatch/write_any.md reads $det_block deterministic clauses from block tags"
else
  bad "ledger_block_tag_scope" "counts: $counts (want a non-zero deterministic column)"
fi

# Dimension 4.4 — the command path. A hook binds one runtime; the rule text
# binds all four, so the requirement has to be IN the rendered rules, not only
# in this repository's settings file.
if grep -q 'doc-read.sh log' "$ROOT/AGENTS.md"; then
  ok "ledger_doc_read_command_documented — AGENTS.md requires the recorded read"
else
  bad "ledger_doc_read_command_documented" "AGENTS.md never names audits/doc-read.sh log"
fi

# Dimension 4.5 — runtime neutrality, as a regression test rather than a
# promise. Vendors add and remove hook features; the day one disappears, the
# gate must behave identically. So no file on the enforcement path may name a
# runtime, its env vars, or its payload shape — that coupling lives only in
# per-runtime configuration, which is deletable without touching enforcement.
neutral=1
for f in "$ROOT/audits/doc-read.sh" "$ROOT/.githooks/pre-commit" \
         "$ROOT/audits/rule-ledger.sh" "$ROOT/audits/rule-ledger-lib.sh"; do
  grep -nE 'PostToolUse|CLAUDE_PROJECT_DIR|tool_input|\.claude/' "$f" >/dev/null 2>&1 && {
    bad "ledger_doc_read_runtime_neutral" "$f names a runtime-specific hook surface"
    neutral=0
    break
  }
done
[ "$neutral" -eq 1 ] && ok "ledger_doc_read_runtime_neutral — enforcement path names no agent runtime"

# --- contract surfaces the spec declares and nothing asserted ----------------

# The Interfaces block promises "0 clean · 1 violation/stale · 2 usage". A
# misuse that exits 1 instead of 2 is indistinguishable from a real violation
# to any caller that branches on the code — make/hook/CI included.
usage_codes_ok=1
usage_note=""
check_code() {
  local want="$1" got="$2" what="$3"
  [ "$got" -eq "$want" ] && return 0
  usage_codes_ok=0; usage_note="$usage_note $what=$got(want $want)"
}
check_code 2 "$(exit_code_of bash "$LEDGER")" "no-mode"
check_code 2 "$(exit_code_of bash "$LEDGER" --nonsense)" "unknown-arg"
check_code 2 "$(exit_code_of bash "$LEDGER" --write)" "write-no-target"
check_code 0 "$(exit_code_of bash "$LEDGER" --help)" "help"
check_code 2 "$(exit_code_of bash "$DOC_READ")" "doc-read-no-mode"
check_code 2 "$(exit_code_of bash "$DOC_READ" log)" "log-no-path"
check_code 2 "$(exit_code_of bash "$DOC_READ" log a b)" "log-extra-arg"
check_code 2 "$(exit_code_of bash "$DOC_READ" check extra)" "check-extra-arg"
if [ "$usage_codes_ok" -eq 1 ]; then
  ok "ledger_usage_exit_codes — every misuse exits 2, --help exits 0"
else
  bad "ledger_usage_exit_codes" "$usage_note"
fi

# Failure Modes row "Renamed/deleted rule doc" on the WRITE path: a render that
# cannot see the whole corpus must not leave a half-true scoreboard on disk.
# Writing a lying file is worse than writing nothing.
sb="$(mk_root)"; rm -f "$sb/docs/VERIFY_TIERS.md"
target="$sb/docs/RULE_ENFORCEMENT.md"
ORLY_ROOT="$sb" bash "$LEDGER" --write "$target" >/dev/null 2>&1; write_rc=$?
if [ "$write_rc" -eq 1 ] && [ ! -f "$target" ]; then
  ok "ledger_write_aborts_on_missing_doc — exit 1 and no scoreboard written"
else
  bad "ledger_write_aborts_on_missing_doc" "exit=$write_rc target-exists=$([ -f "$target" ] && echo yes || echo no)"
fi

# The trigger column's third state. `uncited` and `latent` are different
# findings — nothing points at the doc at all, versus a façade points at it but
# declares no scope — and collapsing them would hide an orphaned rule doc.
sb="$(mk_root)"
ORLY_ROOT="$sb" bash "$LEDGER" --write "$sb/board.md" >/dev/null
if grep -q 'VERIFY_TIERS.md.*| uncited |' "$sb/board.md" \
   && grep -q 'LOGGING_STANDARD.md.*| latent |' "$sb/board.md"; then
  ok "ledger_trigger_uncited — uncited and latent are reported apart"
else
  bad "ledger_trigger_uncited" "$(grep -E 'VERIFY_TIERS|LOGGING_STANDARD' "$sb/board.md" | head -2)"
fi

# A double quote and a backslash are legal in a POSIX filename and illegal raw
# inside a JSON string. Unescaped, the row is unparseable and the reader
# mis-splits it — reporting a path nobody read.
sb="$(mk_repo)"
printf 'x\n' > "$sb/we\"ird.md"
run_doc_read "$sb" log 'we"ird.md' >/dev/null
row="$(tail -1 "$(repo_log "$sb")")"
if printf '%s' "$row" | grep -qF '"path":"we\"ird.md"' \
   && python3 -c "import json,sys; json.loads(sys.argv[1])" "$row" 2>/dev/null; then
  ok "ledger_readlog_escapes_path — a quoted filename still writes parseable JSON"
else
  bad "ledger_readlog_escapes_path" "row: $row"
fi

# A hash that could not be computed proves nothing. Recording a placeholder
# would let two failures compare equal and validate a read of a file that is no
# longer on disk.
sb="$(mk_repo)"
run_doc_read "$sb" log "dispatch/ghost.md" >/dev/null
if [ ! -s "$(repo_log "$sb")" ]; then
  ok "ledger_readlog_fails_closed — an unhashable path records no row"
else
  bad "ledger_readlog_fails_closed" "wrote: $(cat "$(repo_log "$sb")")"
fi

