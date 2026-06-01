#!/usr/bin/env bash
# Negative-test harness for scripts/audit-agents-md.sh.
#
# Conformance + determinism require more than "the audit passes on a good
# tree". They require proof that the audit FAILS on a bad tree — that every
# check actually bites when its invariant is violated. A check that silently
# stops firing (the exact UFS / DESIGN-TOKEN drift this suite already paid
# for) is invisible to a green run. This harness makes that visible.
#
# Method: build a pristine sandbox COPY of the ruleset, apply one targeted
# mutation, run the audit against the sandbox, and assert it exits non-zero
# AND emits the specific FAIL substring. Each mutation maps to one invariant.
#
# Run: bash scripts/test-audit-agents-md.sh   (or `make test-audit`)
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

# Build a self-contained sandbox the audit can run against unmodified.
# The audit derives ROOT from its own location, so a copied script run from
# the sandbox treats the sandbox as ROOT — no env override needed.
make_sandbox() {
  local sb; sb="$(mktemp -d)"
  cp "$SRC_ROOT/AGENTS.md" "$SRC_ROOT/AGENTS_INVARIANCE.md" "$sb/"
  mkdir -p "$sb/scripts/fixtures" "$sb/docs/gates" \
           "$sb/docs/greptile-learnings" "$sb/.githooks"
  cp "$SRC_ROOT/scripts/audit-agents-md.sh" "$sb/scripts/"
  cp "$SRC_ROOT/scripts/audit-data.sh" "$sb/scripts/"
  cp "$SRC_ROOT"/scripts/fixtures/*.diff "$sb/scripts/fixtures/"
  cp "$SRC_ROOT"/docs/gates/*.md "$sb/docs/gates/"
  local d
  for d in TEMPLATE REST_API_DESIGN_GUIDELINES ZIG_RULES BUN_RULES \
           LOGGING_STANDARD LIFECYCLE_PATTERNS; do
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
  bash "$sb/scripts/audit-agents-md.sh" >"$sb/.out" 2>&1; rc=$?
  if [[ $rc -eq 0 ]]; then
    ok "baseline — pristine sandbox PASSES (rc=0)"
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
  bash "$sb/scripts/audit-agents-md.sh" >"$sb/.out" 2>&1; rc=$?
  if [[ $rc -ne 0 ]] && grep -qF "$want" "$sb/.out"; then
    ok "$name"
  else
    bad "$name — rc=$rc, expected FAIL substring not found: '$want'"
    grep -E '🔴' "$sb/.out" | head -3 >&2
  fi
  rm -rf "$sb"
}

printf '%s🔬 Negative-test harness for audit-agents-md.sh%s\n\n' "$B$BO" "$X"

check_baseline
echo

# --- one mutation per invariant ------------------------------------------
expect_fail "gate inventory bites when a gate name is renamed in the index" \
  "gate missing from index: UFS GATE" \
  "perl -pi -e 's/\| UFS GATE \|/| XXX GATE |/' AGENTS.md"

expect_fail "trigger surface bites when an extension is dropped" \
  "trigger surface missing extension: .sql" \
  "perl -pi -e 's/\.sql//g' AGENTS.md"

expect_fail "parity bites when a gate body is deleted (dangling index ref)" \
  "references missing body: docs/gates/ufs.md" \
  "rm docs/gates/ufs.md"

expect_fail "orphan-body bites when a body lacks an AGENTS.md reference" \
  "orphan gate body" \
  "printf '# 🚧 X\n\n**Triggers:** t\n\n**Override:** none\n' > docs/gates/_orphan.md"

expect_fail "gate-body marker bites when **Triggers** is stripped" \
  "missing **Triggers** marker" \
  "perl -0pi -e 's/^\*\*Triggers/REMOVED_Triggers/m' docs/gates/zig.md"

expect_fail "gate-body marker bites when the 🚧 H1 shield is stripped" \
  "missing 🚧 shield in H1" \
  "perl -pi -e 's/^# 🚧 /# /' docs/gates/zig.md"

expect_fail "skill-chain bites when /review-pr is removed from CHORE(close)" \
  "skill chain not in order" \
  "perl -ni -e 'print unless m{/review-pr}' AGENTS.md"

expect_fail "always-forbidden bites when the no-verify ban is removed" \
  "always-forbidden item missing: no-verify" \
  "perl -pi -e 's/no-verify/no_verify_GONE/g' AGENTS.md"

expect_fail "lifecycle bites when a stage header is removed" \
  "lifecycle stage missing: ### VERIFY" \
  "perl -pi -e 's/^### VERIFY\$/### XVERIFY/' AGENTS.md"

expect_fail "HARNESS VERIFY bites when a verdict row keyword is removed" \
  "HARNESS VERIFY row missing: SCHEMA GUARD" \
  "perl -pi -e 's/SCHEMA GUARD/SCHEMA_GUARD_X/g' AGENTS.md"

# Isolated parity mutation: ADD a scenario header without adding a keyword to
# the script's array, so ONLY the count-parity check trips (deleting a
# scenario would conflate parity with the keyword-missing check below).
expect_fail "scenario parity bites when a scenario is added without a keyword" \
  "named-scenario parity" \
  "printf '\n### Scenario 24 — Untracked extra\n' >> AGENTS_INVARIANCE.md"

expect_fail "named-scenario bites when a keyword vanishes" \
  "missing scenario keyword: combined audit" \
  "perl -pi -e 's/combined audit/XXX/g' AGENTS_INVARIANCE.md"

expect_fail "rule-extension bites when a wiring step drops from the recipe" \
  "rule extension protocol missing step keyword: make audit" \
  "perl -pi -e 's/make audit/make_X/g if /Rule extension protocol/' AGENTS.md"

expect_fail "identity bites when the agent handle is removed" \
  "identity handles" \
  "perl -pi -e 's/Orly//g' AGENTS.md"

expect_fail "size bites when AGENTS.md exceeds the byte cap" \
  "exceeds limit" \
  "perl -e 'print \"x\" x 40000' >> AGENTS.md"

expect_fail "parity ref-resolve bites on a dangling index pointer" \
  "references missing body: docs/gates/ghost.md" \
  "printf '| 21 | GHOST | \`docs/gates/ghost.md\` | x |\n' >> AGENTS.md"

expect_fail "self-fingerprint bites when a whole check is deleted from the script" \
  "self-fingerprint: expected check 'identity handles' did not run" \
  "perl -0pi -e 's/if grep -qF \"human is Kishore\".*?\nfi\n//s' scripts/audit-agents-md.sh"

expect_fail "fixture fingerprint bites when dirty.diff is sanitised" \
  "fixture dirty.diff missing M40_001 marker" \
  "perl -pi -e 's/M40_001/CLEAN/g' scripts/fixtures/dirty.diff"

expect_fail "hook trigger bites when pre-push drops its docs/gates guard" \
  "missing docs/gates trigger reference" \
  "perl -pi -e 's{docs/gates}{docs/XXX}g' .githooks/pre-push"

echo
printf '%s' "$BO"
if [[ $BAD -eq 0 ]]; then
  printf '%s✅ %d negative cases + baseline all behaved correctly%s\n' "$G" "$OK" "$X"
  exit 0
else
  printf '%s🔴 %d determinism hole(s) — a check failed to fire%s (%d ok)\n' "$R" "$BAD" "$X" "$OK"
  exit 1
fi
