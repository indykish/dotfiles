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
REGISTERED=(
  "docs/LOGGING_STANDARD.md" "docs/REST_API_DESIGN_GUIDELINES.md"
  "docs/SCHEMA_CONVENTIONS.md" "docs/DOCUMENTATION_RULES.md"
  "docs/LIFECYCLE_PATTERNS.md" "docs/CHANGELOG_VOICE.md"
  "docs/VERIFY_TIERS.md" "docs/greptile-learnings/RULES.md"
)

if [[ -t 1 ]]; then G=$'\033[32m'; R=$'\033[31m'; BO=$'\033[1m'; X=$'\033[0m'
else G=''; R=''; BO=''; X=''; fi
PASS=0; FAIL=0; SANDBOXES=()
cleanup() { local d; for d in "${SANDBOXES[@]+"${SANDBOXES[@]}"}"; do rm -rf "$d"; done; }
trap cleanup EXIT

ok()   { printf '  %sPASS%s  %s\n' "$G" "$X" "$1"; PASS=$((PASS + 1)); }
bad()  { printf '  %sFAIL%s  %s — %s\n' "$R" "$X" "$1" "$2" >&2; FAIL=$((FAIL + 1)); }

# A fixture root carrying every registered doc, so a case under test is the
# only thing that can turn the census red.
mk_root() {
  local sb; sb="$(mktemp -d)"; SANDBOXES+=("$sb")
  mkdir -p "$sb/dispatch" "$sb/docs/greptile-learnings"
  local doc
  for doc in "${REGISTERED[@]}"; do
    printf '# fixture\n\nThe caller MUST do the thing.\n' > "$sb/$doc"
  done
  printf '# façade\n\nReads `docs/LOGGING_STANDARD.md` first.\n' > "$sb/dispatch/write_fixture.md"
  printf '%s' "$sb"
}

run_ledger() { ORLY_ROOT="$1" bash "$LEDGER" --census 2>&1; }
run_reach()  { ORLY_ROOT="$1" bash "$LEDGER" --reachability 2>&1; }
run_check()  { ORLY_ROOT="$1" bash "$LEDGER" --check 2>&1; }

# A façade executable is a file plus one dispatch_init line. Fixtures that need
# a working scope get one; the structural case deliberately omits it.
mk_facade() {
  local root="$1" stem="$2" init="$3"
  printf '#!/usr/bin/env bash\nsource "$(dirname "$0")/lib.sh"\n%s\n' "$init" \
    > "$root/dispatch/$stem.sh"
}

printf '%sledger evals — fixture-pinned census, reachability, scoreboard%s\n\n' "$BO" "$X"

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
