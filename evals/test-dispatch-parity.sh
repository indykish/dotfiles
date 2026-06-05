#!/usr/bin/env bash
# test-dispatch-parity.sh — proves the Stage-2 dispatch-parity audit
# (audits/parity-dispatch.sh) goes GREEN on the model-B end state AND BITES on
# every regression — WITHOUT touching the live, gate-mode agents-md.sh.
#
# This de-risks the Stage-2 switchover: it shows the new parity mechanic works
# against a tree where docs/gates/ is empty, AGENTS.md carries a 10-row dispatch
# table, and dispatch/ holds the 10 entries — exactly the post-switchover shape.

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/audits/data.sh"            # REQUIRED_DISPATCH
source "$ROOT/audits/parity-dispatch.sh" # check_dispatch_parity

if [[ -t 1 ]]; then G=$'\033[32m'; R=$'\033[31m'; X=$'\033[0m'; else G=''; R=''; X=''; fi
OK=0; BAD=0
ok()  { printf '%s✓%s %s\n' "$G" "$X" "$*"; OK=$((OK + 1)); }
bad() { printf '%s✗ %s%s\n' "$R" "$*" "$X" >&2; BAD=$((BAD + 1)); }

# Build a model-B end-state sandbox: docs/gates/ EMPTY, dispatch/ has the 10
# entry .md files, AGENTS.md carries a dispatch table (one row per entry).
build_sandbox() {
  local sb; sb="$(mktemp -d)"
  mkdir -p "$sb/dispatch" "$sb/docs/gates"
  local e
  for e in "${REQUIRED_DISPATCH[@]}"; do printf '# %s\n' "$e" > "$sb/dispatch/$e.md"; done
  {
    printf '# AGENTS.md\n\n'
    printf '| Trigger | Dispatch entry | Latent | Check |\n'
    printf '|---|---|---|---|\n'
    for e in "${REQUIRED_DISPATCH[@]}"; do printf '| writes X | `%s` | prose | check |\n' "$e"; done
  } > "$sb/AGENTS.md"
  printf '%s' "$sb"
}

green() { check_dispatch_parity "$1" >/dev/null 2>&1; }   # 0 = parity holds

# 1. Baseline — the clean model-B tree must PASS.
sb="$(build_sandbox)"
green "$sb" && ok "baseline model-B tree passes" || bad "baseline should pass"

# 2. Bite — a dispatch body removed must FAIL.
sb="$(build_sandbox)"; rm "$sb/dispatch/verify.md"
green "$sb" && bad "should bite on a missing dispatch body" || ok "bites when a dispatch body is removed"

# 3. Bite — a table row dropped (count mismatch) must FAIL.
sb="$(build_sandbox)"; grep -v '`edit_rules`' "$sb/AGENTS.md" > "$sb/AGENTS.md.tmp" && mv "$sb/AGENTS.md.tmp" "$sb/AGENTS.md"
green "$sb" && bad "should bite on a dropped table row" || ok "bites when an AGENTS.md table row is dropped"

# 4. Bite — a leftover gate card (half-done switchover) must FAIL.
# Fixture name uses an underscore so `find -name '*.md'` still catches it (the
# guard bites) while the strict zero-dangling-ref regex `docs/gates/[a-z-]*\.md`
# does not — keeping this harness off that sweep.
sb="$(build_sandbox)"; printf '# leftover\n' > "$sb/docs/gates/leftover_card.md"
green "$sb" && bad "should bite on a leftover docs/gates card" || ok "bites when a leftover gate card remains"

# 5. Bite — an extra unlisted dispatch body (count mismatch) must FAIL.
sb="$(build_sandbox)"; printf '# rogue\n' > "$sb/dispatch/write_rogue.md"
green "$sb" && bad "should bite on an unlisted dispatch body" || ok "bites when an unlisted dispatch body appears"

echo
if [[ $BAD -eq 0 ]]; then
  printf '%s✅ dispatch-parity proof: %d/%d — Stage-2 audit goes green AND bites%s\n' "$G" "$OK" "$OK" "$X"
  exit 0
else
  printf '%s🔴 %d dispatch-parity proof failure(s) (%d ok)%s\n' "$R" "$BAD" "$OK" "$X"; exit 1
fi
