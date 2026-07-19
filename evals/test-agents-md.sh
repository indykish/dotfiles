#!/usr/bin/env bash
# Negative-test harness for audits/agents-md.sh (dispatch model).
#
# Conformance + determinism require more than "the audit passes on a good
# tree". They require proof that the audit FAILS on a bad tree — that every
# check actually bites when its invariant is violated. A check that silently
# stops firing (the exact UFS / DESIGN-TOKEN drift this suite already paid
# for) is invisible to a green run. This harness makes that visible.
#
# Method: build a pristine model-B sandbox COPY of the ruleset (AGENTS.md
# dispatch table + dispatch/*.md façades, NO docs/gates/), apply one targeted
# mutation, run the audit against the sandbox, and assert it exits non-zero
# AND emits the specific FAIL substring. Each mutation maps to one invariant.
#
# Run: bash evals/test-agents-md.sh   (or `make test-audit`)
# Exit 0 = every negative case caught + baseline passes. Non-zero = a check
# failed to fire (a determinism hole) — see ✗ lines.

set -uo pipefail

SRC_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OK=0
BAD=0

if [[ -t 1 ]]; then
  G=$'\033[32m'; R=$'\033[31m'; B=$'\033[34m'; BO=$'\033[1m'; X=$'\033[0m'
else
  G=''; R=''; B=''; BO=''; X=''
fi

ok()  { printf '%s✓%s %s\n' "$G" "$X" "$*"; OK=$((OK + 1)); }
bad() { printf '%s✗ %s%s\n' "$R" "$*" "$X" >&2; BAD=$((BAD + 1)); }

# Build a self-contained model-B sandbox the audit can run against unmodified.
# The audit derives ROOT from its own location, so a copied script run from
# the sandbox treats the sandbox as ROOT — no env override needed.
#
# Model-B end state: AGENTS.md carries the dispatch table, dispatch/ holds the
# matching façades, and docs/gates/ does not exist.
make_sandbox() {
  local sb; sb="$(mktemp -d)"
  cp "$SRC_ROOT/AGENTS.md" "$sb/"
  mkdir -p "$sb/audits/fixtures" "$sb/docs/greptile-learnings" \
           "$sb/dispatch" "$sb/.githooks"
  cp "$SRC_ROOT/audits/agents-md.sh"       "$sb/audits/"
  cp "$SRC_ROOT/audits/agents-md.md"       "$sb/audits/"
  cp "$SRC_ROOT/audits/data.sh"            "$sb/audits/"
  cp "$SRC_ROOT/audits/parity-dispatch.sh" "$sb/audits/"
  cp "$SRC_ROOT"/audits/fixtures/*.diff    "$sb/audits/fixtures/"
  cp "$SRC_ROOT"/dispatch/*.md             "$sb/dispatch/"
  local d
  for d in TEMPLATE REST_API_DESIGN_GUIDELINES LOGGING_STANDARD \
           LIFECYCLE_PATTERNS DOCUMENTATION_RULES ORLY_ARCHITECTURE; do
    cp "$SRC_ROOT/docs/$d.md" "$sb/docs/" 2>/dev/null
  done
  cp "$SRC_ROOT/docs/greptile-learnings/RULES.md" "$sb/docs/greptile-learnings/"
  cp "$SRC_ROOT/.githooks/pre-commit" "$SRC_ROOT/.githooks/pre-push" "$sb/.githooks/"
  printf '%s' "$sb"
}

# Baseline: the pristine copy MUST pass. If it doesn't, every negative result
# below is suspect (the sandbox itself is broken, not the mutation).
check_baseline() {
  local sb rc; sb="$(make_sandbox)"
  bash "$sb/audits/agents-md.sh" >"$sb/.out" 2>&1; rc=$?
  if [[ $rc -eq 0 ]]; then
    ok "baseline — pristine model-B sandbox PASSES (rc=0)"
  else
    bad "baseline — pristine sandbox FAILED (rc=$rc); sandbox build is broken"
    grep -E '🔴|REGRESSION' "$sb/.out" | head
  fi
  rm -rf "$sb"
}

# expect_fail <name> <expected-substring> <mutation-shell-run-in-sandbox>
expect_fail() {
  local name="$1" want="$2" mutate="$3" sb rc
  sb="$(make_sandbox)"
  ( cd "$sb" && eval "$mutate" ) >/dev/null 2>&1
  bash "$sb/audits/agents-md.sh" >"$sb/.out" 2>&1; rc=$?
  if [[ $rc -ne 0 ]] && grep -qF "$want" "$sb/.out"; then
    ok "$name"
  else
    bad "$name — rc=$rc, expected FAIL substring not found: '$want'"
    grep -E '🔴' "$sb/.out" | head -3 >&2
  fi
  rm -rf "$sb"
}

printf '%s🔬 Negative-test harness for agents-md.sh (dispatch model)%s\n\n' "$B$BO" "$X"

check_baseline
echo

# --- one mutation per invariant ------------------------------------------

# Check 1 — dispatch inventory: an entry renamed out of the table's 2nd column.
expect_fail "dispatch inventory bites when an entry is renamed in the table" \
  "dispatch entry missing from table: write_sql" \
  "perl -pi -e 's/write_sql/write_xxx/g' AGENTS.md"

# Check 9b — dispatch parity: a façade body removed (disk < table).
expect_fail "dispatch parity bites when a dispatch body is deleted" \
  "dispatch entry has no body: dispatch/verify.md" \
  "rm dispatch/verify.md"

# Check 9b — dispatch parity: an extra unlisted table row (table > disk).
expect_fail "dispatch parity bites when an extra unlisted row is added" \
  "dispatch parity" \
  "printf '| writes X | \`write_rogue\` | prose | check |\n' >> AGENTS.md"

# Check 9b — dispatch parity: a leftover gate card (half-done switchover).
# Fixture name uses an underscore (leftover_card.md) so `find -name '*.md'`
# still catches it (the guard bites) while the strict zero-dangling-ref regex
# `docs/gates/[a-z-]*\.md` does not — keeping this harness off that sweep.
expect_fail "dispatch parity bites when a leftover gate card remains" \
  "switchover incomplete" \
  "mkdir -p docs/gates && printf '# leftover\n' > docs/gates/leftover_card.md"

# Check 7 — cross-references: a dotfiles-resident doc named by AGENTS.md vanishes.
# Use a non-dispatch resident (docs/TEMPLATE.md) so this isolates check 7
# without also tripping dispatch parity.
expect_fail "cross-reference bites when a resident doc is missing" \
  "dotfiles-resident ref missing: docs/TEMPLATE.md" \
  "rm docs/TEMPLATE.md"

expect_fail "trigger surface bites when an extension is dropped" \
  "trigger surface missing extension: .sql" \
  "perl -pi -e 's/\.sql//g' AGENTS.md"

expect_fail "skill-chain bites when kishore-babysit-prs is removed from CHORE(close)" \
  "skill chain not in order" \
  "perl -ni -e 'print unless m{kishore-babysit-prs}' AGENTS.md"

expect_fail "review routing bites when the Codex native route is removed" \
  "Codex dual review sequence missing" \
  "perl -pi -e 's/Codex: native `\/review`/Codex: review removed/' AGENTS.md"

expect_fail "review routing bites when the Codex gstack route is removed" \
  "Codex dual review sequence missing" \
  "perl -pi -e 's/then gstack `\$review`/then gstack review removed/' AGENTS.md"

expect_fail "review routing bites when the gstack route is removed" \
  "gstack review route missing" \
  "perl -pi -e 's/Claude, OpenCode, Amp: gstack `\/review`/Other agents: review removed/' AGENTS.md"

expect_fail "always-forbidden bites when the no-verify ban is removed" \
  "always-forbidden item missing: no-verify" \
  "perl -pi -e 's/no-verify/no_verify_GONE/g' AGENTS.md"

expect_fail "lifecycle bites when a stage header is removed" \
  "lifecycle stage missing: ### REVIEW" \
  "perl -pi -e 's/^### REVIEW\$/### XREVIEW/' AGENTS.md"

expect_fail "CONFORM bites when a verdict row keyword is removed" \
  "CONFORM row missing: SCHEMA GUARD" \
  "perl -pi -e 's/SCHEMA GUARD/SCHEMA_GUARD_X/g' AGENTS.md"

# Isolated parity mutation: ADD a scenario header without adding a keyword to
# the script's array, so ONLY the count-parity check trips (deleting a
# scenario would conflate parity with the keyword-missing check below).
expect_fail "scenario parity bites when a scenario is added without a keyword" \
  "named-scenario parity" \
  "printf '\n### Scenario 99 — Untracked extra\n' >> audits/agents-md.md"

expect_fail "named-scenario bites when a keyword vanishes" \
  "missing scenario keyword: combined audit" \
  "perl -pi -e 's/combined audit/XXX/g' audits/agents-md.md"

expect_fail "rule-extension bites when a wiring step drops from the recipe" \
  "rule extension protocol missing step keyword: make audit" \
  "perl -pi -e 's/make audit/make_X/g if /Rule extension protocol/' AGENTS.md"

expect_fail "identity bites when the agent handle is removed" \
  "identity handles" \
  "perl -pi -e 's/Orly//g' AGENTS.md"

expect_fail "size bites when AGENTS.md exceeds the byte cap" \
  "exceeds limit" \
  "perl -e 'print \"x\" x 40000' >> AGENTS.md"

expect_fail "self-fingerprint bites when a whole check is deleted from the script" \
  "self-fingerprint: expected check 'identity handles' did not run" \
  "perl -0pi -e 's/if grep -qF \"human is Kishore\".*?\nfi\n//s' audits/agents-md.sh"

expect_fail "fixture fingerprint bites when dirty.diff is sanitised" \
  "fixture dirty.diff missing M40_001 marker" \
  "perl -pi -e 's/M40_001/CLEAN/g' audits/fixtures/dirty.diff"

expect_fail "hook trigger bites when pre-push drops its dispatch/ guard" \
  "missing dispatch/ trigger reference" \
  "perl -pi -e 's{dispatch/}{XXX/}g' .githooks/pre-push"

expect_fail "memory discipline bites when the never-write rule is dropped" \
  "memory discipline: never-write-memory rule missing" \
  "perl -pi -e 's/NEVER write to/You may write to/g' AGENTS.md"

echo
printf '%s' "$BO"
if [[ $BAD -eq 0 ]]; then
  printf '%s✅ %d negative cases + baseline all behaved correctly%s\n' "$G" "$OK" "$X"
  exit 0
else
  printf '%s🔴 %d determinism hole(s) — a check failed to fire%s (%d ok)\n' "$R" "$BAD" "$X" "$OK"
  exit 1
fi
