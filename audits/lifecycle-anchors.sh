# shellcheck shell=bash
# lifecycle-anchors.sh — semantic-drift tripwire between the rendered
# operating model and the lifecycle runbook façade. Dispatch parity proves
# INVENTORY (files ↔ table ↔ REQUIRED); this proves the load-bearing lifecycle
# strings exist in BOTH AGENTS.md (each stage's binding essence) and
# dispatch/lifecycle.md (the runbook), so neither side can drift away from the
# other while `make audit` stays green. Anchor list: LIFECYCLE_ANCHORS in
# audits/data.sh — extend it when a new load-bearing string lands in both.
#
# Sourced by audits/agents-md.sh (label: "lifecycle anchors").
#   check_lifecycle_anchors <ROOT>   # echoes FAIL lines, returns 0/1

check_lifecycle_anchors() {
  local root="$1" rc=0 anchor
  for anchor in "${LIFECYCLE_ANCHORS[@]}"; do
    grep -qF -- "$anchor" "$root/AGENTS.md" \
      || { echo "FAIL: lifecycle anchor missing from AGENTS.md: $anchor"; rc=1; }
    grep -qF -- "$anchor" "$root/dispatch/lifecycle.md" \
      || { echo "FAIL: lifecycle anchor missing from dispatch/lifecycle.md: $anchor"; rc=1; }
  done
  return $rc
}
