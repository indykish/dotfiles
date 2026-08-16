#!/usr/bin/env bash
# evals/ledger/run.sh — fixture-driven proof for audits/rule-ledger.sh.
#
# Each case builds a throwaway ORLY_ROOT (docs/ + dispatch/) and asserts the
# ledger's exit code and output against it. ORLY_ROOT is the only injection
# point: the registry stays hardcoded in the library, so these exercise the
# real code path rather than a test-only branch.
set -uo pipefail

# An inherited GIT_DIR/GIT_INDEX_FILE from a hook redirects any git a child
# runs at the caller's repository (see .githooks/pre-commit). Nothing here
# needs the caller's git scope.
unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE GIT_COMMON_DIR GIT_PREFIX \
      GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LEDGER="$ROOT/audits/rule-ledger.sh"
DOC_READ="$ROOT/audits/doc-read.sh"
# shellcheck source=evals/ledger/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

printf '%sledger evals — census, reachability, scoreboard, doc-read%s\n\n' "$BO" "$X"

# Dimension 1.1 — one row per registered doc, columns machine-parseable.
sb="$(mk_root)"; out="$(run_ledger "$sb")"; rc=$?
rows="$(printf '%s' "$out" | grep -c 'clauses=')"
if [ "$rc" -eq 0 ] && [ "$rows" -eq "${#REGISTERED[@]}" ]; then
  ok "ledger_census_rows — ${#REGISTERED[@]} rows, exit 0"
else
  bad "ledger_census_rows" "exit=$rc rows=$rows (want ${#REGISTERED[@]})"
fi

# Dimension 1.2 — a cited-but-unregistered doc is a structural red.
sb="$(mk_root)"
printf '# façade\n\nReads `docs/BOGUS_RULES.md` before editing.\n' > "$sb/dispatch/write_bogus.md"
out="$(run_ledger "$sb")"; rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'docs/BOGUS_RULES.md'; then
  ok "ledger_census_parity_red — exit 1, names the unregistered doc"
else
  bad "ledger_census_parity_red" "exit=$rc (want 1) naming BOGUS_RULES"
fi

# Dimension 1.2b — a registered doc missing from disk is also structural.
sb="$(mk_root)"; rm -f "$sb/docs/VERIFY_TIERS.md"
out="$(run_ledger "$sb")"; rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'MISSING from disk'; then
  ok "ledger_census_missing_doc_red — exit 1, names the absent path"
else
  bad "ledger_census_missing_doc_red" "exit=$rc (want 1) naming a missing path"
fi

# Dimension 1.3 — UNENFORCED counts as its own class, not as untagged.
sb="$(mk_root)"
cat > "$sb/docs/LOGGING_STANDARD.md" <<'DOC'
# fixture

Callers MUST scope every logger. [UNENFORCED → no parser for scope names]
Secrets MUST NEVER reach a log line. [UNENFORCED → judgment at write time]
Handlers MUST emit an error_code.
DOC
out="$(run_ledger "$sb")"; rc=$?
row="$(printf '%s' "$out" | grep 'LOGGING_STANDARD')"
if [ "$rc" -eq 0 ] \
   && printf '%s' "$row" | grep -q 'unenforced=2' \
   && printf '%s' "$row" | grep -q 'untagged=1'; then
  ok "ledger_unenforced_class — unenforced=2, untagged=1 (not folded together)"
else
  bad "ledger_unenforced_class" "row: $row"
fi

# Dimension 2.1 — fire counts come from real history, not a fixture. write_any
# globs every source extension this repository authors, so a window that found
# nothing means the replay is broken.
out="$(ORLY_ROOT="$ROOT" bash "$LEDGER" --reachability 2>&1)"; rc=$?
fires="$(printf '%s' "$out" | grep 'facade=write_any ' | grep -oE 'fires=[0-9]+' | cut -d= -f2)"
if [ "$rc" -eq 0 ] && [ -n "$fires" ] && [ "$fires" -gt 0 ]; then
  ok "ledger_reachability_counts — write_any fired $fires times over real history"
else
  bad "ledger_reachability_counts" "exit=$rc write_any fires='${fires:-none}' (want > 0)"
fi

# Dimension 2.2 — a façade executable declaring no scope is structural: no diff
# can ever reach the rules it carries, so silence would hide a dead page.
sb="$(mk_root)"
mk_facade "$sb" "write_scoped" "dispatch_init \"FIX\" '*.fixture'"
mk_facade "$sb" "write_scopeless" "# no dispatch_init here"
out="$(run_reach "$sb")"; rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'dispatch/write_scopeless.sh'; then
  ok "ledger_reachability_structural_red — exit 1, names the scope-less façade"
else
  bad "ledger_reachability_structural_red" "exit=$rc (want 1) naming write_scopeless.sh"
fi

# Dimension 3.1 — the scoreboard is a pure function of the tree. A timestamp or
# a commit hash in the render would show up here as a diff between two runs one
# second apart, and would make every unrelated commit a stale-scoreboard red.
sb="$(mk_root)"
ORLY_ROOT="$sb" bash "$LEDGER" --write "$sb/first.md" >/dev/null
ORLY_ROOT="$sb" bash "$LEDGER" --write "$sb/second.md" >/dev/null
if diff -q "$sb/first.md" "$sb/second.md" >/dev/null 2>&1; then
  ok "ledger_write_deterministic — two renders of one tree are byte-identical"
else
  bad "ledger_write_deterministic" "$(diff "$sb/first.md" "$sb/second.md" | head -3)"
fi

# Dimension 3.2 — currency: an absent scoreboard reds, a rendered one greens,
# and editing a registered doc without regenerating reds again. Regeneration is
# the only way back to green, so the committed numbers cannot drift from source.
sb="$(mk_root)"
run_check "$sb" >/dev/null; absent_rc=$?
mkdir -p "$sb/docs"
ORLY_ROOT="$sb" bash "$LEDGER" --write "$sb/docs/RULE_ENFORCEMENT.md" >/dev/null
run_check "$sb" >/dev/null; fresh_rc=$?
printf 'A caller MUST now do one more thing.\n' >> "$sb/docs/CHANGELOG_VOICE.md"
out_stale="$(run_check "$sb")"; stale_rc=$?
ORLY_ROOT="$sb" bash "$LEDGER" --write "$sb/docs/RULE_ENFORCEMENT.md" >/dev/null
run_check "$sb" >/dev/null; regen_rc=$?
if [ "$absent_rc" -eq 1 ] && [ "$fresh_rc" -eq 0 ] && [ "$stale_rc" -eq 1 ] \
   && [ "$regen_rc" -eq 0 ] && printf '%s' "$out_stale" | grep -q -- '--write'; then
  ok "ledger_check_currency — absent 1, fresh 0, stale 1 with the fix command, regenerated 0"
else
  bad "ledger_check_currency" "absent=$absent_rc fresh=$fresh_rc stale=$stale_rc regen=$regen_rc"
fi

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
check_code 2 "$(exit_code_of bash "$LEDGER" --reachability -n notanumber)" "n-nonnumeric"
check_code 2 "$(exit_code_of bash "$LEDGER" --reachability -n 0)" "n-zero"
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

# Failure Modes row "Zero-fire false alarm" — a dormant surface warns, never
# reds. A façade for a language this repository does not author yet must not
# fail anyone's build.
sb="$(mk_root)"
mk_facade "$sb" "write_dormant" "dispatch_init \"DORM\" '*.nothing-matches-this'"
out="$(run_reach "$sb")"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '🟠 no fire in the window'; then
  ok "ledger_reachability_zero_fire_warns — dormant scope warns 🟠 and exits 0"
else
  bad "ledger_reachability_zero_fire_warns" "exit=$rc (want 0 with a 🟠 line)"
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
if grep -q 'VERIFY_TIERS.md.*uncited' "$sb/board.md" \
   && grep -q 'LOGGING_STANDARD.md.*latent' "$sb/board.md"; then
  ok "ledger_trigger_uncited — uncited and latent are reported apart"
else
  bad "ledger_trigger_uncited" "$(grep -E 'VERIFY_TIERS|LOGGING_STANDARD' "$sb/board.md" | head -2)"
fi

# Invariant 1 — read-only: no reporting mode may write into its own root.
sb="$(mk_root)"; mk_facade "$sb" "write_scoped" "dispatch_init \"FIX\" '*.fixture'"
before="$(find "$sb" -type f | sort | xargs shasum 2>/dev/null | shasum)"
run_ledger "$sb" >/dev/null
run_reach "$sb" >/dev/null
run_check "$sb" >/dev/null
after="$(find "$sb" -type f | sort | xargs shasum 2>/dev/null | shasum)"
if [ "$before" = "$after" ]; then
  ok "ledger_census_read_only — fixture root byte-identical after census, reachability, check"
else
  bad "ledger_census_read_only" "a read-only mode mutated its root"
fi

printf '\n%s%d passed, %d failed%s\n' "$BO" "$PASS" "$FAIL" "$X"
[ "$FAIL" -eq 0 ]
