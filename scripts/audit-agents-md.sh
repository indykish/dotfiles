#!/usr/bin/env bash
# Deterministic audit for AGENTS.md.
# Exit 0 = all checks pass. Non-zero = regression — see FAIL lines on stderr.
#
# Run before every AGENTS.md change (and from the pre-commit hook).
# Each check asserts an invariant that, if broken, would re-introduce a
# concrete failure mode the operating model already paid for.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AGENTS="$ROOT/AGENTS.md"
FIXTURES="$ROOT/scripts/fixtures"
GATES_DIR="$ROOT/docs/gates"
FAIL=0

# Colours — disable when stdout is not a TTY (e.g. piped, hook).
if [[ -t 1 ]]; then
  C_GREEN=$'\033[32m'; C_RED=$'\033[31m'; C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'; C_BOLD=$'\033[1m';  C_RESET=$'\033[0m'
else
  C_GREEN=''; C_RED=''; C_YELLOW=''; C_BLUE=''; C_BOLD=''; C_RESET=''
fi

fail() { printf '%s🔴 FAIL%s: %s\n' "$C_RED" "$C_RESET" "$*" >&2; FAIL=1; }
pass() { printf '%s🟢 PASS%s: %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%s🟡 WARN%s: %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
info() { printf '%sℹ️  %s%s\n' "$C_BLUE" "$*" "$C_RESET"; }

info "Auditing $AGENTS"

[[ -f "$AGENTS" ]] || { echo "FAIL: $AGENTS missing" >&2; exit 2; }

# ---------------------------------------------------------------------------
# 1. Gate inventory — every named gate still exists.
# ---------------------------------------------------------------------------
REQUIRED_GATES=(
  "Invariance Suite Gate"
  "RULE NLR" "RULE NLG" "Legacy-Design Consult Guard"
  "Schema Table Removal Guard" "File & Function Length Gate"
  "Milestone-ID Gate" "Architecture Consult & Update Gate"
  "ZIG GATE" "Pub Surface & Struct-Shape Gate"
  "UI Component Substitution Gate" "GREPTILE GATE" "Verification Gate"
)
missing_gates=0
for g in "${REQUIRED_GATES[@]}"; do
  grep -qF "$g" "$AGENTS" || { fail "gate missing: $g"; missing_gates=1; }
done
[[ $missing_gates -eq 0 ]] && pass "gate inventory (${#REQUIRED_GATES[@]} gates present)"

# ---------------------------------------------------------------------------
# 2. Trigger surface — every source/config language has at least one mention.
# ---------------------------------------------------------------------------
EXTS=( ".zig" ".ts" ".tsx" ".js" ".jsx" ".py" ".rs" ".go" ".sh" ".sql" )
missing_exts=0
for ext in "${EXTS[@]}"; do
  grep -qF "$ext" "$AGENTS" || { fail "trigger surface missing extension: $ext"; missing_exts=1; }
done
[[ $missing_exts -eq 0 ]] && pass "trigger surface (${#EXTS[@]} extensions named)"

# ---------------------------------------------------------------------------
# 3. Override syntax present file-wide (every gate either has an Override:
#    line or an explicit "no override" marker).
# ---------------------------------------------------------------------------
override_hits=$(grep -cE 'Override|no override|SKIPPED per' "$AGENTS")
if [[ $override_hits -lt 7 ]]; then
  fail "override-syntax mentions only $override_hits — expected ≥ 7"
else
  pass "override syntax ($override_hits mentions)"
fi

# ---------------------------------------------------------------------------
# 4. Always-forbidden invariance — the six hard bans must remain.
# ---------------------------------------------------------------------------
FORBIDDEN_KEYS=(
  "no-verify"               # hooks/signing
  "Plaintext secrets"       # entity tables
  "Static strings in SQL"   # schema literals
  "Resolving/printing credentials"
  "Force-push default"
  "core paths"              # install-process launches in core paths
)
missing_bans=0
for k in "${FORBIDDEN_KEYS[@]}"; do
  grep -qF "$k" "$AGENTS" || { fail "always-forbidden item missing: $k"; missing_bans=1; }
done
[[ $missing_bans -eq 0 ]] && pass "always-forbidden list (${#FORBIDDEN_KEYS[@]} bans present)"

# ---------------------------------------------------------------------------
# 5. Skill-chain order — /write-unit-test → /review → /review-pr → babysit.
# ---------------------------------------------------------------------------
awk '
  /\/write-unit-test/ && !a { a=NR }
  /\/review[^-]/ && a && !b { b=NR }
  /\/review-pr/ && b && !c { c=NR }
  /kishore-babysit-prs/ && c && !d { d=NR }
  END { exit (a && b && c && d && a<b && b<c && c<d) ? 0 : 1 }
' "$AGENTS" \
  && pass "skill-chain ordering" \
  || fail "skill chain not in order: /write-unit-test → /review → /review-pr → kishore-babysit-prs"

# ---------------------------------------------------------------------------
# 6. HARNESS VERIFY rows — every gate's keyword appears in the verdict block.
# ---------------------------------------------------------------------------
HARNESS_KEYS=(
  "FILE SHAPE" "PUB GATE" "LENGTH GATE" "MILESTONE-ID GATE"
  "ZIG GATE" "UI GATE" "SCHEMA GUARD" "GREPTILE GATE"
  "Architecture consult"
)
missing_rows=0
for kw in "${HARNESS_KEYS[@]}"; do
  grep -qF "$kw" "$AGENTS" || { fail "HARNESS VERIFY row missing: $kw"; missing_rows=1; }
done
[[ $missing_rows -eq 0 ]] && pass "HARNESS VERIFY coverage (${#HARNESS_KEYS[@]} rows present)"

# ---------------------------------------------------------------------------
# 7. Cross-references — dotfiles-resident docs must exist.
#    Project-side docs (AUTH.md, architecture/, changelog.mdx, etc.) live
#    in each project repo, not here, so they're excluded from this check.
# ---------------------------------------------------------------------------
DOTFILES_RESIDENT=(
  "docs/TEMPLATE.md"
  "docs/REST_API_DESIGN_GUIDELINES.md"
  "docs/ZIG_RULES.md"
  "docs/greptile-learnings/RULES.md"
)
broken_refs=0
for doc in "${DOTFILES_RESIDENT[@]}"; do
  if grep -qF "$doc" "$AGENTS"; then
    [[ -f "$ROOT/$doc" ]] || { fail "dotfiles-resident ref missing: $doc"; broken_refs=1; }
  fi
done
[[ $broken_refs -eq 0 ]] && pass "cross-references (dotfiles-resident docs exist)"

# ---------------------------------------------------------------------------
# 8. Combined-audit smoke — the awk pass flags real violations and ignores
#    clean diffs. Fixtures live in scripts/fixtures/.
# ---------------------------------------------------------------------------
read -r -d '' AWK_PROG <<'AWKEOF' || true
/^\+\+\+ b\// { f=$2; sub("^b/","",f); next }
/^\+/ {
  if (f ~ /\.(zig|sql|ts|tsx|js|jsx|py|rs|go|sh|toml|yaml|json)$/ && f !~ /^(docs|node_modules|vendor|third_party)\//) {
    if (match($0, /M[0-9]+_[0-9]+|§[0-9]+(\.[0-9]+)+|\bT[0-9]+\b|\bdim [0-9]+\.[0-9]+\b/)) print "MS-ID:" f
  }
  if (f ~ /\.zig$/ && $0 ~ /^\+(pub | *pub fn | *[A-Z][a-zA-Z]+,$)/) print "PUB:" f
  if (f ~ /^ui\/packages\/app\/.*\.(tsx|jsx)$/ && $0 ~ /<(section|button|input|dialog|article|nav|header|form)\b/) print "UI:" f
}
AWKEOF

if [[ -f "$FIXTURES/dirty.diff" && -f "$FIXTURES/clean.diff" ]]; then
  dirty_hits=$(awk "$AWK_PROG" "$FIXTURES/dirty.diff" | wc -l | tr -d ' ')
  clean_hits=$(awk "$AWK_PROG" "$FIXTURES/clean.diff" | wc -l | tr -d ' ')
  if [[ $dirty_hits -ge 1 ]]; then
    pass "audit fixture: dirty diff flagged ($dirty_hits hits)"
  else
    fail "audit fixture: dirty diff produced 0 hits — awk audit is broken"
  fi
  if [[ $clean_hits -eq 0 ]]; then
    pass "audit fixture: clean diff produced 0 hits"
  else
    fail "audit fixture: clean diff falsely flagged ($clean_hits hits)"
  fi
else
  fail "audit fixture files missing under $FIXTURES/"
fi

# ---------------------------------------------------------------------------
# 9. Gate-body completeness — every gate referenced by AGENTS.md has a
#    body file under docs/gates/<slug>.md, and that body carries the
#    three required structural markers (Triggers, Override, body content).
# ---------------------------------------------------------------------------
GATE_FILES=(
  "docs/gates/invariance-suite.md"
  "docs/gates/nlr.md"
  "docs/gates/nlg.md"
  "docs/gates/legacy-design.md"
  "docs/gates/schema-removal.md"
  "docs/gates/file-length.md"
  "docs/gates/milestone-id.md"
  "docs/gates/architecture.md"
  "docs/gates/zig.md"
  "docs/gates/pub-surface.md"
  "docs/gates/ui-substitution.md"
  "docs/gates/greptile.md"
  "docs/gates/verification.md"
)
gate_body_fail=0
for gf in "${GATE_FILES[@]}"; do
  full="$ROOT/$gf"
  if [[ ! -f "$full" ]]; then
    fail "gate body missing: $gf"; gate_body_fail=1; continue
  fi
  grep -qE '^\*\*Triggers' "$full"   || { fail "$gf missing **Triggers** marker"; gate_body_fail=1; }
  grep -qE '^\*\*Override' "$full"   || { fail "$gf missing **Override** marker"; gate_body_fail=1; }
  grep -qE '^# 🛡️ '          "$full" || { fail "$gf missing 🛡️ shield in H1";    gate_body_fail=1; }
  # AGENTS.md must point at this gate body
  grep -qF "$gf" "$AGENTS"           || { fail "AGENTS.md does not reference $gf"; gate_body_fail=1; }
done
[[ $gate_body_fail -eq 0 ]] && pass "gate bodies complete (${#GATE_FILES[@]} files, each with Triggers + Override + 🛡️ + AGENTS.md ref)"

# ---------------------------------------------------------------------------
# 10. AGENTS_INVARIANCE.md presence + basic shape (questionnaire layer).
# ---------------------------------------------------------------------------
INV="$ROOT/AGENTS_INVARIANCE.md"
if [[ -f "$INV" ]]; then
  inv_scenarios=$(grep -cE '^### Scenario [0-9]+' "$INV")
  if [[ $inv_scenarios -ge 8 ]]; then
    pass "AGENTS_INVARIANCE.md present ($inv_scenarios scenarios)"
  else
    fail "AGENTS_INVARIANCE.md only $inv_scenarios scenarios — expected ≥ 8"
  fi
else
  fail "AGENTS_INVARIANCE.md missing"
fi

# ---------------------------------------------------------------------------
# 11. Size cap — soft guard against drift back to bloat.
#     Default is 25 KB (post-split AGENTS.md is ~24 KB); override via env.
# ---------------------------------------------------------------------------
SIZE=$(wc -c < "$AGENTS" | tr -d ' ')
LIMIT=${AGENTS_MD_SIZE_LIMIT:-27648}  # 27 KB — accommodates 13-gate index incl. meta-gate
if [[ $SIZE -le $LIMIT ]]; then
  pass "size $SIZE bytes (limit $LIMIT)"
else
  fail "size $SIZE bytes exceeds limit $LIMIT (override via AGENTS_MD_SIZE_LIMIT=...)"
fi

# ---------------------------------------------------------------------------
echo
if [[ $FAIL -eq 0 ]]; then
  printf '%s✅ ALL CHECKS PASSED%s\n' "$C_GREEN$C_BOLD" "$C_RESET"
  exit 0
else
  printf '%s🔴 REGRESSION DETECTED%s — see FAIL lines above\n' "$C_RED$C_BOLD" "$C_RESET"
  exit 1
fi
