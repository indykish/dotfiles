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

printf '%sledger evals — census, scoreboard, doc-read%s\n\n' "$BO" "$X"

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

# Dimension 2.2 — a façade executable declaring no scope is structural: no diff
# can ever reach the rules it carries, so silence would hide a dead page. This
# is the half of the retired reachability mode that answers from the tree, so
# it gates inside the census rather than in a report nothing consumed.
sb="$(mk_root)"
mk_facade "$sb" "write_scoped" "dispatch_init \"FIX\" '*.fixture'"
mk_facade "$sb" "write_scopeless" "# no dispatch_init here"
out="$(run_ledger "$sb")"; rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'dispatch/write_scopeless.sh'; then
  ok "ledger_census_facade_scope_red — exit 1, names the scope-less façade"
else
  bad "ledger_census_facade_scope_red" "exit=$rc (want 1) naming write_scopeless.sh"
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

# shellcheck source=evals/ledger/doc_read_cases.sh
source "$(dirname "${BASH_SOURCE[0]}")/doc_read_cases.sh"

# --- review findings, pinned ---------------------------------------------------

# "Pure function of the tree" has to survive a contributor with a different
# LC_ALL. `sort` collates by locale (C: `A-Z B-X a_y`; en_US: `a_y A-Z B-X`), and
# make audit byte-compares this file, so an unpinned collation reds the audit for
# everyone the moment a document carries two codes.
sb="$(mk_root)"
printf '# fixture\n\n> [DETERMINISTIC → B-X]\n\nOne MUST hold.\n\n> [DETERMINISTIC → a_y]\n\nTwo MUST hold.\n\n> [DETERMINISTIC → A-Z]\n\nThree MUST hold.\n' \
  > "$sb/docs/LOGGING_STANDARD.md"
LC_ALL=C ORLY_ROOT="$sb" bash "$LEDGER" --write "$sb/c.md" >/dev/null
LC_ALL=en_US.UTF-8 ORLY_ROOT="$sb" bash "$LEDGER" --write "$sb/utf.md" >/dev/null
if diff -q "$sb/c.md" "$sb/utf.md" >/dev/null 2>&1; then
  ok "ledger_write_locale_stable — multi-code rows render identically under C and en_US"
else
  bad "ledger_write_locale_stable" "$(diff "$sb/c.md" "$sb/utf.md" | head -4)"
fi

# Invariant 1 — read-only: no reporting mode may write into its own root.
sb="$(mk_root)"; mk_facade "$sb" "write_scoped" "dispatch_init \"FIX\" '*.fixture'"
before="$(find "$sb" -type f | sort | xargs shasum 2>/dev/null | shasum)"
run_ledger "$sb" >/dev/null
run_check "$sb" >/dev/null
after="$(find "$sb" -type f | sort | xargs shasum 2>/dev/null | shasum)"
if [ "$before" = "$after" ]; then
  ok "ledger_census_read_only — fixture root byte-identical after census and check"
else
  bad "ledger_census_read_only" "a read-only mode mutated its root"
fi

printf '\n%s%d passed, %d failed%s\n' "$BO" "$PASS" "$FAIL" "$X"
[ "$FAIL" -eq 0 ]
