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
# Modes:
#   --diff   (default) audit files in `git diff --name-only origin/main`
#   --all    audit the whole worktree (slower; periodic runs)
#
# Exits 0 clean, 1 on any blocking violation.

set -euo pipefail

MODE="${1:---diff}"
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

case "$MODE" in
  --diff|diff)
    BASE="${UFS_BASE:-origin/main}"
    git fetch --quiet origin main 2>/dev/null || true
    mapfile -t FILES < <(git diff --name-only "$BASE"...HEAD 2>/dev/null | while read -r f; do
      [ -f "$f" ] && is_source "$f" && echo "$f"
    done)
    ;;
  --all|all)
    mapfile -t FILES < <(git ls-files | while read -r f; do
      is_source "$f" && echo "$f"
    done)
    ;;
  *)
    printf "usage: %s [--diff | --all]\n" "$0" >&2
    exit 2
    ;;
esac

[ "${#FILES[@]}" -eq 0 ] && { ok "audit-ufs: no source files in scope"; exit 0; }

# ── 1. string-dup-file ──────────────────────────────────────────────────────
# Extract double-quoted string literals (best-effort regex; ignores escapes
# inside strings — fine for this discipline check, not a parser). Skip
# 1-char strings, common short labels, doc-strings, JSON keys.

for f in "${FILES[@]}"; do
  # Strip line comments first to avoid matching strings in commentary.
  # Then extract every "..." literal, sort, count, flag any with count ≥2
  # whose value length ≥2 and isn't a bare punctuation char.
  #
  # `|| true` on the two grep stages keeps `set -euo pipefail` from killing
  # the audit when a file has zero double-quoted literals (e.g. a TS
  # config file using only single-quoted strings — vitest.config.ts is
  # the canonical example). Empty pipe input is a valid "no violations in
  # this file" signal, not a failure.
  #
  # NOTE: there is a long-standing latent bug where the `while record`
  # subshell does not propagate FAIL / violations back to the parent —
  # so the string-dup audit silently passes even when violations exist.
  # That deserves its own dedicated cleanup pass (≈275 pre-existing
  # violations would surface); fixing it together with the grep-empty
  # guard would expand this script's blast radius mid-flight.
  awk '
    # Drop line comments (// ... and # ...) but keep block comments visible
    # — they would need a multiline strip; the noise is acceptable.
    { sub(/\/\/.*$/, ""); print }
  ' "$f" \
  | { grep -oE '"[^"]{2,}"' || true; } \
  | { grep -vE '^"(http|https|file|/|\\\\|\\\\n)' || true; } \
  | sort | uniq -c | awk '$1 >= 2 { sub(/^[ \t]+/, ""); print }' \
  | while IFS= read -r line; do
      count="${line%% *}"
      literal="${line#* }"
      record "string-dup-file $f $literal $count"
    done
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

for f in "${FILES[@]}"; do
  # Walk lines with awk; track previous line to allow above-line carve-out.
  awk -v file="$f" -v re="$NUMERIC_RE" '
    BEGIN { prev = "" }
    {
      line = $0
      is_pin_now   = (line ~ /pin test: literal is the contract/)
      is_pin_above = (prev ~ /pin test: literal is the contract/)
      is_const_decl = (line ~ /(^|[[:space:]])(pub[[:space:]]+const|export[[:space:]]+const|const)[[:space:]]/)
      stripped = line
      sub(/\/\/.*$/, "", stripped)
      sub(/#.*$/, "", stripped)
      if (!is_pin_now && !is_pin_above && !is_const_decl && match(stripped, re)) {
        printf "numeric-suspect %s:%d %s\n", file, NR, substr(stripped, RSTART, RLENGTH)
      }
      prev = line
    }
  ' "$f" | while IFS= read -r row; do
      record "$row"
    done
done

# ── 3. cross-runtime-orphan ─────────────────────────────────────────────────
# Full-codebase ERR_* parity check. Scoped to ERR_* prefix because that's
# the cross-runtime contract surface (server error codes consumed by
# clients). Server (Zig) is the source of truth — every JS/TS ERR_* must
# have a matching Zig pub const ERR_*. Zig-only ERR_* consts are fine
# (server-internal codes don't need a client mirror).
#
# Always runs (both --diff and --all). Pre-commit-friendly: scans the
# *working tree* via `git ls-files`, which sees staged content even
# before it lands in HEAD — closing the previous diff-mode blindspot
# where a fix staged in pre-commit couldn't satisfy a check that only
# read committed history.

zig_err=$(git ls-files -- 'src/*.zig' 2>/dev/null \
  | grep -vE '_test\.zig$|^src/zbench_fixtures\.zig$' \
  | xargs -I{} grep -hE '^pub const ERR_[A-Z][A-Z0-9_]+[[:space:]]*=' {} 2>/dev/null \
  | grep -oE 'ERR_[A-Z][A-Z0-9_]+' | sort -u || true)

js_err=$(git ls-files -- 'zombiectl/src/*.js' 'zombiectl/src/*.jsx' 'zombiectl/src/*.ts' 'zombiectl/src/*.tsx' 2>/dev/null \
  | grep -vE '\.test\.|\.spec\.' \
  | xargs -I{} grep -hE '^export const ERR_[A-Z][A-Z0-9_]+[[:space:]]*=' {} 2>/dev/null \
  | grep -oE 'ERR_[A-Z][A-Z0-9_]+' | sort -u || true)

ui_err=$(git ls-files -- 'ui/packages/*/src/*.ts' 'ui/packages/*/src/*.tsx' 2>/dev/null \
  | grep -vE '\.test\.|\.spec\.' \
  | xargs -I{} grep -hE '^export const ERR_[A-Z][A-Z0-9_]+[[:space:]]*=' {} 2>/dev/null \
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
