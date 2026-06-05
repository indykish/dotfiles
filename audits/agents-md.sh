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
FIXTURES="$ROOT/audits/fixtures"
GATES_DIR="$ROOT/docs/gates"
FAIL=0

# Expectation tables (EXPECTED_LABELS, REQUIRED_GATES, EXTS, FORBIDDEN_KEYS,
# HARNESS_KEYS, DOTFILES_RESIDENT, LIFECYCLE_HEADERS, NAMED_SCENARIOS,
# RULE_EXTENSION_STEPS, AWK_PROG) live in the sibling data file — split out
# to keep this audit under the LENGTH GATE cap. Data drift is itself caught
# by the gate-parity + named-scenario-parity checks below.
DATA="$ROOT/audits/data.sh"
[[ -f "$DATA" ]] || { echo "FAIL: $DATA missing (audit data tables)" >&2; exit 2; }
# shellcheck source=audits/data.sh
. "$DATA"
SEEN_LABELS=()

# Colours — disable when stdout is not a TTY (e.g. piped, hook).
if [[ -t 1 ]]; then
  C_GREEN=$'\033[32m'; C_RED=$'\033[31m'; C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'; C_BOLD=$'\033[1m';  C_RESET=$'\033[0m'
else
  C_GREEN=''; C_RED=''; C_YELLOW=''; C_BLUE=''; C_BOLD=''; C_RESET=''
fi

fail() { printf '%s🔴 FAIL%s: %s\n' "$C_RED" "$C_RESET" "$*" >&2; FAIL=1; SEEN_LABELS+=("$*"); }
pass() { printf '%s🟢 PASS%s: %s\n' "$C_GREEN" "$C_RESET" "$*";       SEEN_LABELS+=("$*"); }
warn() { printf '%s🟡 WARN%s: %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
info() { printf '%s🔆 %s%s\n' "$C_BLUE" "$*" "$C_RESET"; }

info "Auditing $AGENTS"

[[ -f "$AGENTS" ]] || { echo "FAIL: $AGENTS missing" >&2; exit 2; }

# ---------------------------------------------------------------------------
# 1. Gate inventory — every named gate still exists (REQUIRED_GATES in data).
# ---------------------------------------------------------------------------
missing_gates=0
for g in "${REQUIRED_GATES[@]}"; do
  # The name must appear as the Gate COLUMN value of an index row — i.e.
  # right after a "| " cell delimiter ("| <name>") — on a line that ALSO
  # carries a docs/gates/ body reference. Rationale for each part:
  #   * A file-wide substring match was too loose: the same row's override
  #     text repeats the name (·`$g: SKIPPED…`) on the very line holding the
  #     docs/gates/ path, so renaming the Gate column kept the check green.
  #   * The "| " prefix anchors to the column cell; the override repetition
  #     is preceded by a backtick, not "| ", so it no longer satisfies it.
  #   * We do NOT require a trailing " |": row 1's cell carries a "(meta)"
  #     suffix, and REQUIRED_GATES stores the bare name.
  # (Both failure shapes are pinned by the negative harness; see
  #  evals/test-agents-md.sh.)
  grep -F "| $g" "$AGENTS" | grep -q 'docs/gates/' \
    || { fail "gate missing from index: $g"; missing_gates=1; }
done
[[ $missing_gates -eq 0 ]] && pass "gate inventory (${#REQUIRED_GATES[@]} gates present in index)"

# ---------------------------------------------------------------------------
# 2. Trigger surface — every source/config language has a mention (EXTS in data).
# ---------------------------------------------------------------------------
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
# 4. Always-forbidden invariance — six hard bans (FORBIDDEN_KEYS in data).
# ---------------------------------------------------------------------------
missing_bans=0
for k in "${FORBIDDEN_KEYS[@]}"; do
  grep -qF "$k" "$AGENTS" || { fail "always-forbidden item missing: $k"; missing_bans=1; }
done
[[ $missing_bans -eq 0 ]] && pass "always-forbidden list (${#FORBIDDEN_KEYS[@]} bans present)"

# ---------------------------------------------------------------------------
# 5. Skill-chain order — /write-unit-test → /review → /review-pr → babysit.
#    Anchored to within the CHORE(close) section so a stray earlier mention
#    cannot satisfy the check.
# ---------------------------------------------------------------------------
awk '
  /^### CHORE \(close\)/                  { in_section=1; next }
  /^### |^## /                            { if (in_section) in_section=0 }
  in_section && /\/write-unit-test/  && !a { a=NR }
  in_section && /\/review[^-]/       && a && !b { b=NR }
  in_section && /\/review-pr/        && b && !c { c=NR }
  in_section && /kishore-babysit-prs/&& c && !d { d=NR }
  END { exit (a && b && c && d && a<b && b<c && c<d) ? 0 : 1 }
' "$AGENTS" \
  && pass "skill-chain ordering (anchored to CHORE(close))" \
  || fail "skill chain not in order within CHORE(close): /write-unit-test → /review → /review-pr → kishore-babysit-prs"

# ---------------------------------------------------------------------------
# 6. HARNESS VERIFY rows — every gate keyword in the verdict block (HARNESS_KEYS).
# ---------------------------------------------------------------------------
missing_rows=0
for kw in "${HARNESS_KEYS[@]}"; do
  grep -qF "$kw" "$AGENTS" || { fail "HARNESS VERIFY row missing: $kw"; missing_rows=1; }
done
[[ $missing_rows -eq 0 ]] && pass "HARNESS VERIFY coverage (${#HARNESS_KEYS[@]} rows present)"

# ---------------------------------------------------------------------------
# 7. Cross-references — dotfiles-resident docs must exist (DOTFILES_RESIDENT
#    in data). Project-side docs (AUTH.md, architecture/, changelog.mdx) live
#    in each project repo, not here, so they're excluded from this check.
# ---------------------------------------------------------------------------
broken_refs=0
for doc in "${DOTFILES_RESIDENT[@]}"; do
  if grep -qF "$doc" "$AGENTS"; then
    [[ -f "$ROOT/$doc" ]] || { fail "dotfiles-resident ref missing: $doc"; broken_refs=1; }
  fi
done
[[ $broken_refs -eq 0 ]] && pass "cross-references (dotfiles-resident docs exist)"

# ---------------------------------------------------------------------------
# 8. Combined-audit smoke — the awk pass (AWK_PROG in data) flags real
#    violations and ignores clean diffs. Fixtures live in audits/fixtures/.
# ---------------------------------------------------------------------------
if [[ -f "$FIXTURES/dirty.diff" && -f "$FIXTURES/clean.diff" ]]; then
  # Fixture content fingerprint — guards against well-meaning rewrites
  # that "fix" dirty.diff to be clean (which would silently break the smoke).
  grep -qF "M40_001"  "$FIXTURES/dirty.diff" || fail "fixture dirty.diff missing M40_001 marker"
  grep -qE '<button>' "$FIXTURES/dirty.diff" || fail "fixture dirty.diff missing raw <button>"
  ! grep -qF "M40_001"  "$FIXTURES/clean.diff" || fail "fixture clean.diff has milestone-id leak"
  ! grep -qE '<button>' "$FIXTURES/clean.diff" || fail "fixture clean.diff has raw <button>"

  dirty_hits=$(awk "$AWK_PROG" "$FIXTURES/dirty.diff" | wc -l | tr -d ' ')
  clean_hits=$(awk "$AWK_PROG" "$FIXTURES/clean.diff" | wc -l | tr -d ' ')

  # Pin exact expected counts — protects against false-positive "smoke ok"
  # where a rigged dirty.diff produces ≥1 hit on an unrelated token.
  if [[ $dirty_hits -eq 4 ]]; then
    pass "audit fixture: dirty diff flagged exactly 4 hits"
  else
    fail "audit fixture: dirty diff flagged $dirty_hits hits (expected 4)"
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
# 9. Gate-body completeness — DERIVED, not hand-listed. The set of gate
#    bodies is computed from disk; each must carry the three structural
#    markers (Triggers, Override, 🚧 H1) AND be referenced by AGENTS.md.
#    A hand-maintained array was the root cause of UFS/DESIGN-TOKEN drift
#    (bodies on disk + in the AGENTS.md index, but absent from the array,
#    so the audit silently skipped them). Deriving removes that failure mode.
# ---------------------------------------------------------------------------
mapfile -t GATE_FILES < <(cd "$ROOT" && ls docs/gates/*.md 2>/dev/null | sort)
gate_body_fail=0
if [[ ${#GATE_FILES[@]} -eq 0 ]]; then
  fail "no gate bodies found under docs/gates/"; gate_body_fail=1
fi
for gf in "${GATE_FILES[@]}"; do
  full="$ROOT/$gf"
  grep -qE '^\*\*Triggers' "$full"   || { fail "$gf missing **Triggers** marker"; gate_body_fail=1; }
  grep -qE '^\*\*Override' "$full"   || { fail "$gf missing **Override** marker"; gate_body_fail=1; }
  grep -qE '^# 🚧 '          "$full" || { fail "$gf missing 🚧 shield in H1";    gate_body_fail=1; }
  # AGENTS.md must point at this gate body (no orphan body on disk).
  grep -qF "$gf" "$AGENTS"           || { fail "AGENTS.md does not reference $gf (orphan gate body)"; gate_body_fail=1; }
done
[[ $gate_body_fail -eq 0 ]] && pass "gate bodies complete (${#GATE_FILES[@]} files derived from disk, each with Triggers + Override + 🚧 + AGENTS.md ref)"

# ---------------------------------------------------------------------------
# 9b. Gate parity — the three sources of truth must agree in size, so adding
#     a gate to one place but forgetting another is a hard FAIL:
#       (a) gate-index rows in AGENTS.md (lines carrying a docs/gates/ ref),
#       (b) gate bodies on disk,
#       (c) the REQUIRED_GATES name array (check #1).
#     Also: every docs/gates/ path the AGENTS.md index names must exist on
#     disk (no dangling pointer). This is the structural backstop that the
#     hand-list let slip — it makes "wire it everywhere or fail" mechanical.
# ---------------------------------------------------------------------------
parity_fail=0
index_rows=$(grep -cE '^\| *[0-9]+ .*docs/gates/[a-z0-9-]+\.md' "$AGENTS")
disk_count=${#GATE_FILES[@]}
required_count=${#REQUIRED_GATES[@]}
if [[ "$index_rows" -ne "$disk_count" || "$disk_count" -ne "$required_count" ]]; then
  fail "gate parity mismatch: AGENTS.md index rows=$index_rows, disk bodies=$disk_count, REQUIRED_GATES=$required_count (all three must match)"
  parity_fail=1
fi
# Every index-named body path resolves to a real file.
while IFS= read -r ref; do
  [[ -f "$ROOT/$ref" ]] || { fail "AGENTS.md gate index references missing body: $ref"; parity_fail=1; }
done < <(grep -oE 'docs/gates/[a-z0-9-]+\.md' "$AGENTS" | sort -u)
[[ $parity_fail -eq 0 ]] && pass "gate parity (index=$index_rows ↔ disk=$disk_count ↔ REQUIRED_GATES=$required_count, all index refs resolve)"

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
# 11. Lifecycle stage headers — all present in AGENTS.md (LIFECYCLE_HEADERS).
# ---------------------------------------------------------------------------
missing_stages=0
for h in "${LIFECYCLE_HEADERS[@]}"; do
  grep -qF "$h" "$AGENTS" || { fail "lifecycle stage missing: $h"; missing_stages=1; }
done
[[ $missing_stages -eq 0 ]] && pass "lifecycle stages (${#LIFECYCLE_HEADERS[@]} headers present)"

# ---------------------------------------------------------------------------
# 12. AGENTS_INVARIANCE.md — named scenarios must exist by title
#     (NAMED_SCENARIOS in data). Catches the case where a scenario count
#     stays ≥ threshold but a specific high-value scenario is renamed/removed.
# ---------------------------------------------------------------------------
INV="$ROOT/AGENTS_INVARIANCE.md"
missing_scenarios=0
if [[ -f "$INV" ]]; then
  for s in "${NAMED_SCENARIOS[@]}"; do
    grep -qF "$s" "$INV" || { fail "AGENTS_INVARIANCE.md missing scenario keyword: $s"; missing_scenarios=1; }
  done
  # Parity — the keyword array must keep pace with the actual scenario count,
  # so a newly-added scenario can't sit unguarded (this is exactly how
  # scenarios 20-22 slipped past the keyword list before this check existed).
  actual_scenarios=$(grep -cE '^### Scenario [0-9]+' "$INV")
  if [[ "${#NAMED_SCENARIOS[@]}" -ne "$actual_scenarios" ]]; then
    fail "named-scenario parity: array has ${#NAMED_SCENARIOS[@]} keywords but AGENTS_INVARIANCE.md has $actual_scenarios scenarios (every scenario needs a keyword guard)"
    missing_scenarios=1
  fi
  [[ $missing_scenarios -eq 0 ]] && pass "named scenarios (${#NAMED_SCENARIOS[@]} keywords ↔ $actual_scenarios scenarios, parity holds)"
else
  fail "AGENTS_INVARIANCE.md missing"
fi

# ---------------------------------------------------------------------------
# 13. Hook trigger coverage — pre-commit AND pre-push must reference
#     AGENTS.md AND docs/gates so ruleset changes can never silently
#     bypass either layer.
# ---------------------------------------------------------------------------
PRE_COMMIT="$ROOT/.githooks/pre-commit"
PRE_PUSH="$ROOT/.githooks/pre-push"
hook_fail=0
for hook in "$PRE_COMMIT" "$PRE_PUSH"; do
  name=$(basename "$hook")
  if [[ ! -f "$hook" ]]; then
    fail "hook missing: .githooks/$name"; hook_fail=1; continue
  fi
  grep -qF "AGENTS.md"  "$hook" || { fail "$name missing AGENTS.md trigger reference"; hook_fail=1; }
  grep -qF "docs/gates" "$hook" || { fail "$name missing docs/gates trigger reference"; hook_fail=1; }
done
[[ $hook_fail -eq 0 ]] && pass "hook triggers (.githooks/pre-commit + pre-push both gate AGENTS.md + docs/gates)"

# ---------------------------------------------------------------------------
# 14. Rule extension protocol — AGENTS.md MUST document the 4-step recipe
#     for landing a new rules file or gate body, AND that recipe must still
#     enumerate all four wiring steps. Mere section-presence is not enough:
#     the protocol is the only thing tying a new gate to the doc-reads table,
#     the questionnaire, the DOTFILES_RESIDENT audit list, and `make audit`.
#     If a step silently drops out of the recipe, gates can be added without
#     that linkage — the same class of drift that hid UFS/DESIGN-TOKEN.
# ---------------------------------------------------------------------------
if grep -qF "Rule extension protocol" "$AGENTS"; then
  protocol_line=$(grep -F "Rule extension protocol" "$AGENTS" | head -1)
  rep_fail=0
  for step in "${RULE_EXTENSION_STEPS[@]}"; do
    grep -qF "$step" <<<"$protocol_line" || { fail "rule extension protocol missing step keyword: $step"; rep_fail=1; }
  done
  [[ $rep_fail -eq 0 ]] && pass "rule extension protocol section present (all 4 wiring steps enumerated)"
else
  fail "AGENTS.md missing 'Rule extension protocol' section"
fi

# ---------------------------------------------------------------------------
# 15. Identity handles — AGENTS.md MUST identify the human (Kishore / Indy)
#     and the agent (Oracle / Orly) so addressing resolves unambiguously.
# ---------------------------------------------------------------------------
if grep -qF "human is Kishore" "$AGENTS" && grep -qF "Orly" "$AGENTS"; then
  pass "identity handles (Kishore/Indy ↔ Oracle/Orly present)"
else
  fail "identity handles: AGENTS.md missing 'human is Kishore' or 'Orly'"
fi

# ---------------------------------------------------------------------------
# 16. Size cap — soft guard against drift back to bloat.
#     Default is 25 KB (post-split AGENTS.md is ~24 KB); override via env.
# ---------------------------------------------------------------------------
SIZE=$(wc -c < "$AGENTS" | tr -d ' ')
LIMIT=${AGENTS_MD_SIZE_LIMIT:-29696}  # 29 KB — bumped 2026-05-20 by 1024 B for the Address tags (🤠 Indy / 🦉 Orly) + `usezombie` project-name vocabulary rule in Owner & Style
if [[ $SIZE -le $LIMIT ]]; then
  pass "size $SIZE bytes (limit $LIMIT)"
else
  fail "size $SIZE bytes exceeds limit $LIMIT (override via AGENTS_MD_SIZE_LIMIT=...)"
fi

# ---------------------------------------------------------------------------
# Self-fingerprint — every EXPECTED_LABELS entry must have been emitted by
# at least one pass/fail call. Catches the case where someone deletes a
# check from the script — the script then runs successfully but with
# fewer invariants enforced, which is exactly the kind of silent
# weakening this audit exists to prevent.
# ---------------------------------------------------------------------------
fp_fail=0
for label in "${EXPECTED_LABELS[@]}"; do
  found=0
  for seen in "${SEEN_LABELS[@]}"; do
    [[ "$seen" == *"$label"* ]] && { found=1; break; }
  done
  [[ $found -eq 1 ]] || { fail "self-fingerprint: expected check '$label' did not run"; fp_fail=1; }
done
[[ $fp_fail -eq 0 ]] && pass "self-fingerprint (${#EXPECTED_LABELS[@]} expected checks ran)"

echo
if [[ $FAIL -eq 0 ]]; then
  printf '%s✅ ALL CHECKS PASSED%s\n' "$C_GREEN$C_BOLD" "$C_RESET"
  exit 0
else
  printf '%s🔴 REGRESSION DETECTED%s — see FAIL lines above\n' "$C_RED$C_BOLD" "$C_RESET"
  exit 1
fi
