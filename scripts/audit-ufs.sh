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
# Subshell-propagation fix (M70): the loop reads from a process
# substitution (not a pipe) so `record` mutates FAIL / violations in
# the parent shell. The previous pipe-into-while form ran the loop in
# a subshell and silently dropped violations.
while IFS= read -r row; do
  record "$row"
done < <(awk '
  FNR == 1 {
    prev_file = FILENAME
    # Test files: repetition is fixture data, not magic strings.
    # Skip string-dup-file for tests; other checks still apply.
    is_test = (FILENAME ~ /(_test\.zig|\.test\.|\.spec\.|\.unit\.test|\.integration\.test|\/test\/|\/tests\/)/)
  }
  is_test { next }
  # ui/ files: extracting class-strings or short literals to file-local
  # consts is fragile in TypeScript (type-position uses widen string|
  # literal types, and the cleanup belongs in a UI-aware spec). Skip
  # string-dup-file for ui/packages/*/src; cross-runtime-orphan still
  # runs against ui/ to catch ERR_* parity drift.
  # macOS/BSD awk aborts on a `/` inside a `[...]` class in a regex *literal*
  # ("nonterminated character class"); use a dynamic-regex STRING — identical
  # match on gawk, portable on BWK awk (the macOS default). Do not re-inline.
  FILENAME ~ "^ui/packages/[^/]+/(src|app|tests|components|lib|hooks)/" { next }
  FNR == 1 { in_test_block = 0; test_depth = 0; in_block_comment = 0 }
  {
    line = $0
    # Block-comment exclusion (TS/JS/Zig non-applicable): skip lines inside /* ... */
    if (in_block_comment) {
      if (line ~ /\*\//) in_block_comment = 0
      next
    }
    if (line ~ /\/\*/ && line !~ /\*\//) {
      in_block_comment = 1
      next
    }
    # Zig multi-line string literal — lines start with `\\` after whitespace.
    if (FILENAME ~ /\.zig$/ && line ~ /^[[:space:]]*\\\\/) next
    # Inline-test exclusion (Zig): track depth across `test "..." {` blocks.
    if (FILENAME ~ /\.zig$/) {
      if (in_test_block) {
        test_depth += gsub(/\{/, "{", line) - gsub(/\}/, "}", line)
        if (test_depth <= 0) in_test_block = 0
        line = $0  # restore
        next
      }
      if (line ~ /^test[[:space:]]+"/) {
        in_test_block = 1
        tmp = line
        test_depth = gsub(/\{/, "{", tmp) - gsub(/\}/, "}", tmp)
        if (test_depth <= 0) in_test_block = 0
        next
      }
    }
    sub(/\/\/.*$/, "", line)
    # Strip single-line /* ... */ inline block comments (jsdoc/etc) so
    # literals inside them are not counted.
    gsub(/\/\*[^*]*\*+([^\/*][^*]*\*+)*\//, "", line)
    rest = line
    # Strip Zig identifier-escape syntax @"name" — body is an identifier,
    # not a string literal, but the regex below would otherwise match it.
    gsub(/@"[^"]*"/, "", rest)
    # Strip empty string literals so the regex below cannot fuse
    # two adjacent Zig literals through their inner gap.
    gsub(/""/, "", rest)
    # Match a quoted string literal honouring \" escapes: open quote,
    # then runs of (backslash+any-char) | (non-backslash-non-quote),
    # then close quote. Min 3 chars total ensures literal body ≥1 char
    # (back-compat with the {2,} body-min from the prior regex).
    while (match(rest, /"((\\.)|[^\\"])+"/)) {
      lit = substr(rest, RSTART, RLENGTH)
      rest = substr(rest, RSTART + RLENGTH)
      if (length(lit) < 4) continue
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
' "${FILES[@]}")

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
# so the "prev line carve-out" stays per-file. Process substitution keeps
# the while loop in the parent shell so record() mutates FAIL.
while IFS= read -r row; do
  record "$row"
done < <(awk -v re="$NUMERIC_RE" '
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
' "${FILES[@]}")

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
