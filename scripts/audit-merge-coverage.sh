#!/usr/bin/env bash
# scripts/audit-merge-coverage.sh — merge-loss proof for the resolver migration
# (RESOLVER_ARCHITECTURE.md 6.5, the keystone).
#
# For each of the 15 dissolving authoring cards, assert every non-boilerplate
# token appears in some resolvers/*.md, OR is captured as an explicit Indy-acked
# drop. A card is not deleted (Stage 2) until its assertion is green. This proves
# PROSE-TOKEN COVERAGE only — NOT semantic equivalence and NOT trigger
# enforcement (that is audit-resolver-coverage.sh's tag↔check wiring). Three
# guards close the gameable holes:
#   1. Frozen normalization — pinned in evals/resolver-evals/merge_coverage.py:
#      lowercase, tokenize on [a-z0-9]+, drop a fixed stopword set + tokens
#      shorter than 3 + pure numbers. Not a tunable threshold; a binary
#      present/absent test per token.
#   2. No self-certification — the drops ledger (evals/resolver-evals/merge-coverage-drops.tsv)
#      requires an Indy ack-quote per line; an agent-authored bare drop is
#      rejected and the audit fails.
#   3. Trigger-surface enforcement is separate — handled by the coverage audit.
#
# A negative fixture (fixtures/merge_orphan_card.md, run via --selftest) proves an
# orphaned sentence FAILS — if it ever passes, the proof has gone blind.
#
# Modes:  (default) scan the 15 dissolving cards | --card <file> scan one file |
#         --selftest run the orphan fixture and assert it FAILS.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RES_GLOB="$ROOT/resolvers/*.md"
DROPS="$ROOT/evals/resolver-evals/merge-coverage-drops.tsv"
FIXDIR="$ROOT/evals/resolver-evals/fixtures"
PYCORE="$ROOT/evals/resolver-evals/merge_coverage.py"
GATES="$ROOT/docs/gates"
DISSOLVE=(zig pub-surface lifecycle ui-substitution design-token schema-removal \
          file-length logging milestone-id error-registry ufs greptile nlr nlg \
          legacy-design)

# Thin wrapper over the frozen-normalization core. Card paths are argv; the
# corpus glob + drops ledger travel via the environment.
run_py() { RES_GLOB="$RES_GLOB" DROPS="$DROPS" python3 "$PYCORE" "$@"; }

MODE="${1:-default}"
case "$MODE" in
  --selftest)
    printf 'MERGE COVERAGE — selftest (orphan fixture MUST fail)\n'
    if out="$(run_py "$FIXDIR/merge_orphan_card.md" 2>&1)"; then
      printf '%s\n  ❌ SELFTEST FAIL: orphan card passed — the proof is blind\n' "$out"; exit 1
    else
      printf '%s\n  ✅ SELFTEST PASS: orphan sentence correctly flagged\n' "$out"; exit 0
    fi ;;
  --card)
    printf 'MERGE COVERAGE — single card: %s\n' "${2:?usage: --card <file>}"
    run_py "$2"; exit $? ;;
  default)
    printf 'MERGE COVERAGE AUDIT — 15 dissolving cards → resolver corpus (6.5)\n'
    cards=(); for d in "${DISSOLVE[@]}"; do cards+=("$GATES/$d.md"); done
    if run_py "${cards[@]}"; then
      printf '\n✅ MERGE COVERAGE: every card token covered or acked-dropped\n'; exit 0
    else
      printf '\n❌ MERGE COVERAGE: uncovered tokens above — merge them or add an Indy-acked drop before deleting the card\n'; exit 1
    fi ;;
  *) printf 'usage: %s [--card <file> | --selftest]\n' "$0" >&2; exit 2 ;;
esac
