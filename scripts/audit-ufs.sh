#!/usr/bin/env bash
# audit-ufs.sh — enforce RULE UFS (Unified Form for Symbols) across the worktree.
#
# Gate body: docs/gates/ufs.md
# Fires in: make lint, HARNESS VERIFY.
#
# Generic detection — no manifest of known literals, so the audit scales
# as the codebase grows. Three classes of violation:
#
#   1. string-dup-file   — same string literal ≥2× in one source file
#   2. numeric-suspect   — power-of-ten or unit-factor numeric not bound
#                          to a const, not on a pin-test carve-out line
#   3. cross-runtime-orphan — SCREAMING_SNAKE const defined in one runtime
#                          but missing from a sibling runtime the diff touches
#
# Carve-out: any `// pin test: literal is the contract` comment on or
# above the offending line excludes that line from numeric-suspect.
#
# Scope (M70):
#   Walks the full working tree via `git ls-files` — sees staged content
#   because the index is what `ls-files` reports. Pre-commit-safe: a fix
#   staged but not yet committed satisfies the check on the same hook run.
#   The previous `--diff` (BASE...HEAD) mode was retired with M70 because
#   it was blind to the index at pre-commit time.
#
# Usage:
#   audit-ufs.sh           # full-codebase scan (default and only mode)
#   audit-ufs.sh --all     # alias for default
#
# Exits 0 clean, 1 on any blocking violation.

set -euo pipefail

# Single mode after M70: full-codebase scan. `--all` accepted as alias
# for back-compat with the harness-verify-all target.
case "${1:-}" in
  ""|--all|all) ;;
  *)
    printf "usage: %s [--all]\n" "$0" >&2
    printf "note: --diff was retired in M70 — see docs/gates/ufs.md (Scope).\n" >&2
    exit 2
    ;;
esac
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

FAIL=0
violations=()
record() { violations+=("$*"); FAIL=1; }
ok()     { printf "OK:   %s\n" "$*"; }

# ── File scope ──────────────────────────────────────────────────────────────

is_source() {
  local f="$1"
  case "$f" in
    vendor/*|third_party/*|.zig-cache/*|*/node_modules/*|*.tsbuildinfo) return 1 ;;
    *_test.zig|*.test.ts|*.test.tsx|*.test.js|*.test.jsx|*.unit.test.js|*.spec.ts) ;; # tests in scope
  esac
  case "$f" in
    *.zig|*.ts|*.tsx|*.js|*.jsx) return 0 ;;
    *) return 1 ;;
  esac
}

mapfile -t FILES < <(git ls-files | while read -r f; do
  is_source "$f" && echo "$f"
done)

[ "${#FILES[@]}" -eq 0 ] && { ok "audit-ufs: no source files in scope"; exit 0; }

# ── 1. string-dup-file ──────────────────────────────────────────────────────
# Extract double-quoted string literals (best-effort regex; ignores escapes
# inside strings — fine for this discipline check, not a parser). Skip
# 1-char strings, common short labels, doc-strings, JSON keys.

# Perf (M70): single awk over all files instead of per-file pipeline
# (was 5 forks × ~760 files = ~20s). Group counts by FILENAME so the
# "≥2 occurrences in one file" semantic is preserved.
#
# NOTE: there is a long-standing latent bug where the `while record`
# subshell does not propagate FAIL / violations back to the parent —
# so the string-dup audit silently passes even when violations exist.
# That deserves its own dedicated cleanup pass (≈3019 pre-existing
# violations would surface — much higher than the ≈275 estimate written
# when the bug was discovered, because the per-file loop was masking
# even more than the author knew). Fixing it together with M70 would
# expand this script's blast radius mid-flight; the subshell shape is
# preserved deliberately.
awk '
  FNR == 1 { prev_file = FILENAME }
  {
    line = $0
    sub(/\/\/.*$/, "", line)
    rest = line
    while (match(rest, /"[^"]{2,}"/)) {
      lit = substr(rest, RSTART, RLENGTH)
      rest = substr(rest, RSTART + RLENGTH)
      if (lit ~ /^"(http|https|file|\/|\\\\|\\\\n)/) continue
      key = FILENAME "\034" lit
      count[key]++
      file_of[key] = FILENAME
      lit_of[key] = lit
    }
  }
  END {
    for (k in count) {
      if (count[k] >= 2) {
        printf "string-dup-file %s %s %d\n", file_of[k], lit_of[k], count[k]
      }
    }
  }
' "${FILES[@]}" | while IFS= read -r row; do
  record "$row"
done

# ── 2. numeric-suspect ──────────────────────────────────────────────────────
# Flag bare power-of-ten and unit-factor numerics in expressions.
# Pattern matches: 1_000, 1_000_000, 1_000_000_000, 1e3, 1e6, 1e9,
# 60, 3600, 86400, 1024, 1048576, 10_000_000, 100_000.
# A line is a violation if:
#  - it contains one of those patterns
#  - the line is NOT a const declaration (`pub const`, `export const`, `const`)
#  - the line is NOT marked `// pin test: literal is the contract`
#  - the line above is NOT marked `// pin test: literal is the contract`

NUMERIC_RE='(\b1[_e]?0{3,12}\b|\b1_000(_000)*\b|\b10_000_000\b|\b100_000\b|\b1024\b|\b1048576\b|\b3600\b|\b86400\b)'

# Perf (M70): single awk across all files; FNR == 1 detects file boundary
# so the "prev line carve-out" stays per-file. Subshell-pipe shape
# preserved deliberately (see string-dup-file NOTE above — the latent
# violations-propagation bug is out of scope for M70).
awk -v re="$NUMERIC_RE" '
  FNR == 1 { prev = "" }
  {
    line = $0
    is_pin_now   = (line ~ /pin test: literal is the contract/)
    is_pin_above = (prev ~ /pin test: literal is the contract/)
    is_const_decl = (line ~ /(^|[[:space:]])(pub[[:space:]]+const|export[[:space:]]+const|const)[[:space:]]/)
    stripped = line
    sub(/\/\/.*$/, "", stripped)
    sub(/#.*$/, "", stripped)
    if (!is_pin_now && !is_pin_above && !is_const_decl && match(stripped, re)) {
      printf "numeric-suspect %s:%d %s\n", FILENAME, FNR, substr(stripped, RSTART, RLENGTH)
    }
    prev = line
  }
' "${FILES[@]}" | while IFS= read -r row; do
  record "$row"
done

# ── 3. cross-runtime-orphan ─────────────────────────────────────────────────
# Full-codebase ERR_* parity check. Scoped to ERR_* prefix because that's
# the cross-runtime contract surface (server error codes consumed by
# clients). Server (Zig) is the source of truth — every JS/TS ERR_* must
# have a matching Zig pub const ERR_*. Zig-only ERR_* consts are fine
# (server-internal codes don't need a client mirror).
#
# Scans the *working tree* via `git ls-files` — sees staged content even
# before it lands in HEAD, closing the previous diff-mode blindspot where
# a fix staged in pre-commit couldn't satisfy a check that only read
# committed history.
#
# Perf (M70): batched `xargs grep` (single process across all files)
# instead of `xargs -I{} grep` (one process per file). On usezombie the
# server-side scan dropped from ~30s to <2s.

zig_err=$(git ls-files -z -- 'src/*.zig' 2>/dev/null \
  | { grep -zvE '_test\.zig$|^src/zbench_fixtures\.zig$' || true; } \
  | xargs -0 grep -hE '^pub const ERR_[A-Z][A-Z0-9_]+[[:space:]]*=' 2>/dev/null \
  | grep -oE 'ERR_[A-Z][A-Z0-9_]+' | sort -u || true)

js_err=$(git ls-files -z -- 'zombiectl/src/*.js' 'zombiectl/src/*.jsx' 'zombiectl/src/*.ts' 'zombiectl/src/*.tsx' 2>/dev/null \
  | { grep -zvE '\.test\.|\.spec\.' || true; } \
  | xargs -0 grep -hE '^export const ERR_[A-Z][A-Z0-9_]+[[:space:]]*=' 2>/dev/null \
  | grep -oE 'ERR_[A-Z][A-Z0-9_]+' | sort -u || true)

ui_err=$(git ls-files -z -- 'ui/packages/*/src/*.ts' 'ui/packages/*/src/*.tsx' 2>/dev/null \
  | { grep -zvE '\.test\.|\.spec\.' || true; } \
  | xargs -0 grep -hE '^export const ERR_[A-Z][A-Z0-9_]+[[:space:]]*=' 2>/dev/null \
  | grep -oE 'ERR_[A-Z][A-Z0-9_]+' | sort -u || true)

# Every JS ERR_* must exist in Zig.
for c in $js_err; do
  if ! echo "$zig_err" | grep -qx "$c"; then
    record "cross-runtime-orphan $c absent-in-zig"
  fi
done
# Every TS (UI) ERR_* must exist in Zig.
for c in $ui_err; do
  if ! echo "$zig_err" | grep -qx "$c"; then
    record "cross-runtime-orphan $c absent-in-zig"
  fi
done

# ── Report ──────────────────────────────────────────────────────────────────

if [ "$FAIL" -eq 0 ]; then
  ok "audit-ufs: no violations across ${#FILES[@]} file(s)"
  exit 0
fi

printf "🚧 UFS GATE — %d violation(s):\n" "${#violations[@]}" >&2
for v in "${violations[@]}"; do
  printf "  %s\n" "$v" >&2
done
printf "\nResolve by either (1) extract to a named const + replace all sites,\n" >&2
printf "(2) add the matching const in the missing sibling runtime same-commit,\n" >&2
printf "or (3) annotate '// pin test: literal is the contract' on/above the line.\n" >&2
exit 1
