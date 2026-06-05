#!/usr/bin/env bash
# evals/dispatch/merge-coverage.sh — merge-loss proof for the dispatch migration
# (DISPATCH_ARCHITECTURE.md 6.5, the keystone).
#
# For each of the 15 dissolving authoring cards, assert every non-boilerplate
# token appears in some dispatch/*.md, OR is captured as an explicit Indy-acked
# drop. A card is not deleted (Stage 2) until its assertion is green. This proves
# PROSE-TOKEN COVERAGE only — NOT semantic equivalence and NOT trigger
# enforcement (that is dispatch-coverage.sh's tag↔check wiring). Three
# guards close the gameable holes:
#   1. Frozen normalization — pinned in evals/dispatch/merge_coverage.py:
#      lowercase, tokenize on [a-z0-9]+, drop a fixed stopword set + tokens
#      shorter than 3 + pure numbers. Not a tunable threshold; a binary
#      present/absent test per token.
#   2. Ledger discipline (FORMAT, not authenticity) — each drop in
#      evals/dispatch/merge-coverage-drops.tsv is PER-CARD and must be a
#      single token carrying an Indy ack-quote; a malformed, multi-word, or
#      un-acked line is rejected. This stops a bare/lazy agent self-cert — it
#      CANNOT prove Indy authored the quote (no crypto on a plaintext ledger the
#      agent also writes); ack authenticity is enforced socially at PR review.
#   3. Trigger-surface enforcement is separate — handled by the coverage audit.
#
# A negative fixture (fixtures/merge_orphan_card.md, run via --selftest) proves an
# orphaned sentence FAILS — if it ever passes, the proof has gone blind.
#
# Modes:  (default) scan the 15 dissolving cards | --card <file> scan one file |
#         --selftest run the orphan fixture and assert it FAILS.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RES_GLOB="$ROOT/dispatch/*.md"
DROPS="$ROOT/evals/dispatch/merge-coverage-drops.tsv"
FIXDIR="$ROOT/evals/dispatch/fixtures"
PYCORE="$ROOT/evals/dispatch/merge_coverage.py"
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
    printf 'MERGE COVERAGE — selftest (orphan discriminators MUST be flagged)\n'
    out="$(run_py "$FIXDIR/merge_orphan_card.md" 2>&1)"; rc=$?
    # exit!=0 alone is NOT enough: the fixture's framing prose also contributes
    # uncovered tokens, so a blinded orphan LINE (e.g. via over-stopwording)
    # could still exit 1 while the proof has gone blind. Assert the orphan
    # line's invented discriminators actually appear in the uncovered list.
    miss=""
    for d in quombulent flarnesque zindlewop grobnatically snorklewidget vorpalised; do
      printf '%s' "$out" | grep -qF "$d" || miss="$miss $d"
    done
    if [ "$rc" -ne 0 ] && [ -z "$miss" ]; then
      printf '%s\n  ✅ SELFTEST PASS: orphan discriminators correctly flagged\n' "$out"; exit 0
    else
      printf '%s\n  ❌ SELFTEST FAIL: rc=%s missing:%s — proof is blind\n' "$out" "$rc" "${miss:- none}"; exit 1
    fi ;;
  --card)
    printf 'MERGE COVERAGE — single card: %s\n' "${2:?usage: --card <file>}"
    run_py "$2"; exit $? ;;
  default)
    printf 'MERGE COVERAGE AUDIT — 15 dissolving cards → dispatch corpus (6.5)\n'
    cards=(); for d in "${DISSOLVE[@]}"; do cards+=("$GATES/$d.md"); done
    if run_py "${cards[@]}"; then
      printf '\n✅ MERGE COVERAGE: every card token covered or acked-dropped\n'; exit 0
    else
      printf '\n❌ MERGE COVERAGE: uncovered tokens above — merge them or add an Indy-acked drop before deleting the card\n'; exit 1
    fi ;;
  *) printf 'usage: %s [--card <file> | --selftest]\n' "$0" >&2; exit 2 ;;
esac
