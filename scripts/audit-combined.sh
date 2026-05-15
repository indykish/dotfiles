#!/usr/bin/env bash
# audit-combined.sh — single awk pass over the diff, replaces 4 separate
# self-audits per AGENTS.md "HARNESS VERIFY → Combined end-of-turn audit".
#
# Emits per-line hits for:
#   * MS-ID — milestone-id leak in source/config (M{N}_{NNN}, §X.Y, T{N},
#             dim {N}.{N}) outside docs/ + node_modules/ + vendor/.
#             Test files are NOT exempt (RULE TST-NAM).
#   * PUB   — unannounced `pub` declaration in *.zig (struct field or fn).
#   * UI    — raw HTML element in ui/packages/app/*.{tsx,jsx} where a
#             design-system primitive exists (UI Component Substitution Gate).
#
# Non-empty hit list → exit 1. Otherwise exit 0 + one OK line.
#
# Per-check scope (M70):
#   Unlike the rest of the audit-*.sh family, this script stays
#   diff-shaped (asserts on *added* `^\+` lines, not file state).
#   Each sub-check's rule is shaped as "don't introduce X" rather than
#   "X must not exist anywhere", so a full-codebase scan would change
#   the semantic:
#     * MS-ID — flags milestone identifiers added in this commit.
#               Historical docs in `done/` legitimately contain them,
#               and code comments may reference them in old commits.
#               Only newly-added M{N}_{NNN} citations should fail.
#     * PUB   — flags unannounced `pub` declarations introduced now.
#               Pre-existing pub surface is owned by the architecture
#               doc; only *new* unannounced pub is a violation.
#     * UI    — flags raw HTML primitives added now where a design-system
#               component exists. Legacy raw-HTML in unrelated files is
#               cleaned by the touch-it-fix-it rule (RULE NLR), not by
#               this audit's scope.
#
#   Conversion to full-codebase scope is a separate research spec — see
#   M70_001 §3 + Failure Modes. The M70 thesis (pre-commit sees staged
#   content) holds here too: `git diff --cached` reads the index, so the
#   staged-not-committed slip is not a risk for this script's checks.
#
# Modes:
#   --staged  (default) diff against `git diff --cached -U0`
#             — pre-commit context; index includes staged content
#   --diff              diff against origin/main (vs BASE...HEAD)
#             — used by `make harness-verify-all` periodic deep audit
#
# Gate bodies:
#   docs/gates/milestone-id.md
#   docs/gates/pub-surface.md
#   docs/gates/ui-substitution.md

set -euo pipefail

MODE="${1:---staged}"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

case "$MODE" in
  --staged|staged)
    DIFF_CMD="git diff --cached -U0"
    LABEL="staged"
    ;;
  --diff|diff)
    BASE="${BASE:-origin/main}"
    if ! git rev-parse --verify "$BASE" >/dev/null 2>&1; then BASE="HEAD"; fi
    DIFF_CMD="git diff -U0 ${BASE}...HEAD"
    LABEL="vs $BASE"
    ;;
  --all|all)
    # No "all" mode — combined audit is diff-shaped by construction (it
    # asserts on *added* lines, not file state). Force callers to pick.
    echo "usage: $0 [--staged|--diff]" >&2
    exit 2
    ;;
  *)
    echo "usage: $0 [--staged|--diff]" >&2; exit 2 ;;
esac

# Single awk pass; reads stdin (the unified diff).
#
# Block-scope tracking for the variant-line clause: a line like `BrokenPipe,`
# looks identical whether its enclosing `enum|struct|error{` is `pub` or not.
# `private_block` tracks whether we're inside an explicitly-private block
# within this diff so clause 3 fires only on variants in pub blocks.
# Conservative default (unknown scope → flag) preserves prior behavior when
# the block opening is outside the staged diff.
hits=$($DIFF_CMD | awk '
  /^\+\+\+ b\// { f=$2; sub("^b/","",f); private_block=0; next }
  /^@@/ { private_block=0; next }
  /^-/ { next }
  /^\+/ {
    line=$0
    sub(/^\+/,"",line)

    if (line ~ /^pub const [A-Za-z_][A-Za-z0-9_]* *= *(enum|struct|error)/) {
      private_block = 0
    } else if (line ~ /^const [A-Za-z_][A-Za-z0-9_]* *= *(enum|struct|error)/) {
      private_block = 1
    } else if (line ~ /^\}/) {
      private_block = 0
    }

    if (f ~ /\.(zig|sql|ts|tsx|js|jsx|py|rs|go|sh|toml|yaml|json)$/ &&
        f !~ /^(docs|node_modules|vendor|third_party)\//) {
      if (match(line, /M[0-9]+_[0-9]+|§[0-9]+(\.[0-9]+)+|\bT[0-9]+\b|\bdim [0-9]+\.[0-9]+\b/)) {
        print "MS-ID  " f ": " line
      }
    }
    if (f ~ /\.zig$/) {
      if (line ~ /^(pub | *pub fn )/) {
        print "PUB    " f ": " line
      } else if (line ~ /^ *[A-Z][a-zA-Z]+,$/ && !private_block) {
        print "PUB    " f ": " line
      }
    }
    if (f ~ /^ui\/packages\/app\/.*\.(tsx|jsx)$/ &&
        line ~ /<(section|button|input|dialog|article|nav|header|form)[ \t>\/]/) {
      print "UI     " f ": " line
    }
  }
')

if [ -n "$hits" ]; then
  echo "FAIL: combined audit ($LABEL) — MS-ID / PUB / UI hits below"
  printf '%s\n' "$hits"
  echo
  echo "Resolve each hit OR carve out via the relevant gate's override comment."
  echo "  MS-ID — strip the marker; production code must be milestone-free (RULE TST-NAM)"
  echo "  PUB   — print PUB GATE block before commit; verify external consumer grep"
  echo "  UI    — use the design-system primitive; carve out with 'UI GATE: SKIPPED'"
  exit 1
fi

echo "OK:   combined audit ($LABEL) — 0 hits"
