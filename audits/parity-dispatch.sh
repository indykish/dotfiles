#!/usr/bin/env bash
# parity-dispatch.sh — the Stage-2 replacement for agents-md.sh's gate parity.
#
# Model B dissolves docs/gates/ (20 cards) into dispatch/ (10 entries). At the
# Stage-2 switchover, agents-md.sh's gate-parity block (`index ↔ disk ↔
# REQUIRED_GATES`, over docs/gates/) is deleted and this is sourced + called in
# its place — line-neutral, so the ≤350 length gate on agents-md.sh still holds.
#
# Until then it is exercised only by evals/test-dispatch-parity.sh against a
# model-B sandbox, proving the switchover audit goes GREEN and BITES before any
# card is deleted. It does not run on the live (gate-mode) tree.
#
#   check_dispatch_parity <ROOT>   # echoes PASS/FAIL lines, returns 0/1
#
# Sources of truth (must agree):
#   (a) disk     — dispatch/*.md   (each entry has exactly one latent .md)
#   (b) index    — AGENTS.md dispatch-table rows (2nd cell a backticked entry)
#   (c) expected — REQUIRED_DISPATCH (audits/data.sh)

check_dispatch_parity() {
  local root="$1" rc=0 e
  local agents="$root/AGENTS.md"   # separate line: $root must be set before it expands here
  local bt='`'                     # backtick held in a var (literal ` is fine, but keep it explicit)

  local disk_count table_rows required_count
  disk_count=$(find "$root/dispatch" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  table_rows=$(grep -cE "^\|[^|]*\| *${bt}[a-z_]+${bt} *\|" "$agents" 2>/dev/null)
  required_count=${#REQUIRED_DISPATCH[@]}

  if [[ "$disk_count" -ne "$table_rows" || "$table_rows" -ne "$required_count" ]]; then
    echo "FAIL: dispatch parity — disk=$disk_count ↔ table=$table_rows ↔ REQUIRED=$required_count (all three must match)"
    rc=1
  fi

  for e in "${REQUIRED_DISPATCH[@]}"; do
    [[ -f "$root/dispatch/$e.md" ]] \
      || { echo "FAIL: dispatch entry has no body: dispatch/$e.md"; rc=1; }
    grep -qE "^\|[^|]*\| *${bt}$e${bt} *\|" "$agents" 2>/dev/null \
      || { echo "FAIL: dispatch entry absent from AGENTS.md table: $e"; rc=1; }
  done

  # docs/gates/ must be EMPTY in the dispatch model (the old empty-set guard
  # inverts: a leftover card means the switchover is half-done).
  local leftover
  leftover=$(find "$root/docs/gates" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  [[ "$leftover" -eq 0 ]] \
    || { echo "FAIL: docs/gates/ still holds $leftover card(s) — switchover incomplete"; rc=1; }

  [[ $rc -eq 0 ]] && echo "PASS: dispatch parity (disk=$disk_count ↔ table=$table_rows ↔ REQUIRED=$required_count; docs/gates/ empty)"
  return $rc
}
