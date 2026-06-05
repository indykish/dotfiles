#!/usr/bin/env bash
# evals/dispatch/coverage.sh — coherence audit for the dispatch façade
# pairs (DISPATCH_ARCHITECTURE.md 6.3 + 6.4).
#
# Proves COMPLETENESS and SYMBOL-PRESENCE across five artifacts — the latent
# .md tags, the deterministic .sh dispatch rows, the prose-pinned fixtures, the
# comprehension probes, and the canonical gloss legend. It does NOT judge prose
# semantics (that is the dispatch-evals fixtures' job, 6.1). Fails (exit 1) if:
#
#   (a) a [DETERMINISTIC → CODE] tag has no row for CODE in ANY dispatch .sh.
#       Universal-code carve-out (Decision 6): a code wired once in its home
#       façade (e.g. UFS in write_any) satisfies the tag wherever it appears.
#   (b) a run-enforced DETERMINISTIC code has no pass+fail fixture in run.sh.
#       Delegated codes (dispatch_delegate) and TODO-CHECK/NEW: are exempt.
#   (c) a [JUDGMENT → CODE] tag has no comprehension probe in fixtures.jsonl.
#   (d) a .sh CODE row has no tag in any dispatch .md (orphan check, global).
#   (e) a dispatch_run_helper delegates to a leaf that is absent/non-executable.
#   (f) a code emitted by a .sh row has no entry in lib.sh DISPATCH_GLOSS.
#   (g) the RULES.md canonical gloss legend diverges from lib.sh DISPATCH_GLOSS.
#
# Exemptions are deliberate: TODO-CHECK marks a build-the-check stub; NEW:<name>
# marks a proposed-not-yet-existing code; both predate any .sh row, fixture, or
# probe by definition. Run from the dotfiles repo root (dotfiles-internal, like
# dispatch-evals — not synced into product repos).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RES="$ROOT/dispatch"
SCR="$ROOT/audits"
RULES="$ROOT/docs/greptile-learnings/RULES.md"
EVALS="$ROOT/evals/dispatch/run.sh"
PROBES="$ROOT/evals/llms/fixtures.jsonl"

if [[ -t 1 ]]; then G=$'\033[32m'; R=$'\033[31m'; BO=$'\033[1m'; X=$'\033[0m'
else G=''; R=''; BO=''; X=''; fi
RC=0
fail() { printf '    %s🔴 %s%s\n' "$R" "$1" "$X"; RC=1; }
okln() { printf '    %s🟢%s %s\n' "$G" "$X" "$1"; }
sec()  { printf '\n%s%s%s\n' "$BO" "$1" "$X"; }

# ---- extraction (grep -oE + sed; no awk — macOS BWK-awk portability) --------
# Tag codes by kind. The legend placeholder [DETERMINISTIC → <CODE>] is excluded
# automatically: '<' is not in the code character class.
det_tags() { grep -hoE '\[DETERMINISTIC → [A-Z0-9_:-]+\]' "$RES"/*.md \
  | sed -E 's/.* → ([A-Z0-9_:-]+)\]/\1/' | sort -u; }
jud_tags() { grep -hoE '\[JUDGMENT → [A-Z0-9_:-]+\]' "$RES"/*.md \
  | sed -E 's/.* → ([A-Z0-9_:-]+)\]/\1/' | sort -u; }
# A code is exempt from check (a)/(c) if it is a stub or proposed marker.
real() { grep -vE '^(TODO-CHECK|NEW:)'; }

# .sh dispatch rows, classified by the lib.sh helper that wraps them. Real .sh
# codes are [A-Z0-9_-] only (no colon) — colon codes (NEW:*) are .md-tag-only
# proposed markers, never legal in a live dispatch row; this class matches the
# gloss/fixture extractors below so all .sh-code handling agrees.
sh_runhelper() { grep -hoE '^dispatch_run_helper +"[A-Z0-9_-]+"' "$RES"/*.sh \
  | sed -E 's/.*"([A-Z0-9_-]+)"/\1/' | sort -u; }
sh_delegate() { grep -hoE '^dispatch_delegate +"[A-Z0-9_-]+"' "$RES"/*.sh \
  | sed -E 's/.*"([A-Z0-9_-]+)"/\1/' | sort -u; }
sh_judgment() { grep -hoE '^dispatch_judgment +"[A-Z0-9_-]+"' "$RES"/*.sh \
  | sed -E 's/.*"([A-Z0-9_-]+)"/\1/' | sort -u; }
sh_lengthgate() { grep -qE '^dispatch_length_gate ' "$RES"/*.sh && echo FLL; }
# run_helper rows as "CODE script" pairs (for the leaf-presence check).
sh_helper_pairs() { grep -hoE '^dispatch_run_helper +"[A-Z0-9_-]+" +"[^"]+"' "$RES"/*.sh \
  | sed -E 's/^dispatch_run_helper +"([A-Z0-9_-]+)" +"([^"]+)".*/\1 \2/'; }

# Run-enforced (needs fixture) vs all-emitted (needs tag + gloss).
run_enforced() { { sh_lengthgate; sh_runhelper; } | sort -u; }
all_sh_codes() { { sh_lengthgate; sh_runhelper; sh_delegate; sh_judgment; } | sort -u; }

# Set membership: is $1 a line in the newline list on stdin?
in_list() { grep -qxF "$1"; }

# ---- check (a) — every DETERMINISTIC tag has a run/delegate .sh row ---------
check_tag_to_check() {
  sec "(a) DETERMINISTIC tag → .sh row (universal-code carve-out, global)"
  local backed code; backed="$( { run_enforced; sh_delegate; } | sort -u )"
  while IFS= read -r code; do
    [ -z "$code" ] && continue
    if printf '%s\n' "$backed" | in_list "$code"; then okln "$code — wired in some dispatch .sh"
    else fail "$code — DETERMINISTIC tag with no run/delegate row in any dispatch .sh"; fi
  done < <(det_tags | real)
}

# ---- check (b) — run-enforced code has pass+fail fixture --------------------
check_fixture_coverage() {
  sec "(b) run-enforced DETERMINISTIC code → pass+fail fixture (delegated exempt)"
  local specs; specs="$(grep -oE '"[^"]+\.zig\|[^"]+\|[01]\|[A-Z0-9_-]+"' "$EVALS" | tr -d '"')"
  local code has0 has1 line ex c
  while IFS= read -r code; do
    [ -z "$code" ] && continue
    has0=0; has1=0
    while IFS='|' read -r _ _ _ ex c; do
      [ "$c" = "$code" ] || continue
      [ "$ex" = "0" ] && has0=1; [ "$ex" = "1" ] && has1=1
    done <<<"$specs"
    if [ "$has0" = 1 ] && [ "$has1" = 1 ]; then okln "$code — pass + fail fixture present"
    else fail "$code — missing $([ $has0 = 0 ] && echo pass) $([ $has1 = 0 ] && echo fail) fixture in dispatch-evals"; fi
  done < <(run_enforced | real)
}

# ---- check (c) — every JUDGMENT tag has a comprehension probe ---------------
check_probe_coverage() {
  sec "(c) JUDGMENT tag → comprehension probe (fixtures.jsonl mode dispatch-judgment-<code>)"
  local code lc
  while IFS= read -r code; do
    [ -z "$code" ] && continue
    lc="$(printf '%s' "$code" | tr '[:upper:]' '[:lower:]')"
    if grep -qF "\"mode\":\"dispatch-judgment-$lc\"" "$PROBES"; then okln "$code — probe present"
    else fail "$code — JUDGMENT tag with no comprehension probe (expected mode dispatch-judgment-$lc)"; fi
  done < <(jud_tags | real)
}

# ---- check (d) — orphan: every .sh code is tagged somewhere -----------------
check_orphan() {
  sec "(d) .sh code → tag in some dispatch .md (orphan check, global)"
  local tags code; tags="$( { det_tags; jud_tags; } | sort -u )"
  while IFS= read -r code; do
    [ -z "$code" ] && continue
    if printf '%s\n' "$tags" | in_list "$code"; then okln "$code — tagged in some .md"
    else fail "$code — .sh dispatch row with no [.. → $code] tag in any dispatch .md"; fi
  done < <(all_sh_codes)
}

# ---- check (e) — run_helper leaf present + executable -----------------------
check_leaf_presence() {
  sec "(e) dispatch_run_helper leaf present + executable"
  local code script path
  while read -r code script; do
    [ -z "$code" ] && continue
    path="$SCR/$script"
    if [ -f "$path" ] && [ -x "$path" ]; then okln "$code → audits/$script (present, executable)"
    else fail "$code → audits/$script absent or non-executable — silent-green hole"; fi
  done < <(sh_helper_pairs)
}

# ---- check (f) — no naked codes: every .sh code has a lib.sh gloss ----------
gloss_lib() { grep -E '^[[:space:]]*\[[A-Z0-9_-]+\]="' "$RES/lib.sh" \
  | sed -E 's/^[[:space:]]*\[([A-Z0-9_-]+)\]="(.*)"[[:space:]]*$/\1\t\2/'; }
check_gloss_presence() {
  sec "(f) .sh code → lib.sh DISPATCH_GLOSS entry (no naked codes)"
  local codes code; codes="$(gloss_lib | cut -f1)"
  while IFS= read -r code; do
    [ -z "$code" ] && continue
    if printf '%s\n' "$codes" | in_list "$code"; then okln "$code — gloss present"
    else fail "$code — emitted by a .sh row but has no DISPATCH_GLOSS entry"; fi
  done < <(all_sh_codes)
}

# ---- check (g) — RULES.md canonical legend == lib.sh DISPATCH_GLOSS ---------
gloss_rules() { sed -n '/^## Rule-code gloss legend (canonical)/,/^## RULE NDC/p' "$RULES" \
  | grep -E '^\| [A-Z0-9_-]+ \|' | grep -vE '^\| CODE \|' \
  | sed -E 's/^\| ([A-Z0-9_-]+) \| (.*) \|$/\1\t\2/'; }
check_gloss_divergence() {
  sec "(g) RULES.md canonical legend ↔ lib.sh DISPATCH_GLOSS (byte-identical map)"
  local nl nr; nl="$(gloss_lib | wc -l | tr -d ' ')"; nr="$(gloss_rules | wc -l | tr -d ' ')"
  if [ "$nl" -eq 0 ] || [ "$nr" -eq 0 ]; then
    fail "gloss legend parsed to 0 rows (lib.sh=$nl, RULES.md=$nr) — heading/format reworded? empty≠identical"
    return
  fi
  local d; d="$(diff <(gloss_lib | sort) <(gloss_rules | sort) || true)"
  if [ -z "$d" ]; then okln "gloss maps identical ($nl codes)"
  else fail "gloss divergence between lib.sh and RULES.md:"; printf '%s\n' "$d" | sed 's/^/        /'; fi
}

printf '%sDISPATCH COVERAGE AUDIT — façade-pair coherence (6.3 + 6.4)%s\n' "$BO" "$X"
check_tag_to_check
check_fixture_coverage
check_probe_coverage
check_orphan
check_leaf_presence
check_gloss_presence
check_gloss_divergence

if [ "$RC" -eq 0 ]; then printf '\n%s✅ DISPATCH COVERAGE: ALL CHECKS PASSED%s\n' "$G$BO" "$X"
else printf '\n%s❌ DISPATCH COVERAGE: coherence gaps above — fix before commit%s\n' "$R$BO" "$X"; fi
exit "$RC"
