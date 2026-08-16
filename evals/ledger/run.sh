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

printf '%sledger evals — fixture-pinned census behaviour%s\n\n' "$BO" "$X"

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

# Invariant 1 — read-only: the census must not write into its own root.
sb="$(mk_root)"; before="$(find "$sb" -type f | sort | xargs shasum 2>/dev/null | shasum)"
run_ledger "$sb" >/dev/null
after="$(find "$sb" -type f | sort | xargs shasum 2>/dev/null | shasum)"
if [ "$before" = "$after" ]; then
  ok "ledger_census_read_only — fixture root byte-identical after a run"
else
  bad "ledger_census_read_only" "the census mutated its root"
fi

printf '\n%s%d passed, %d failed%s\n' "$BO" "$PASS" "$FAIL" "$X"
[ "$FAIL" -eq 0 ]
