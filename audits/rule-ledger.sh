#!/usr/bin/env bash
# rule-ledger.sh — what each rule document actually enforces.
#
#   audits/rule-ledger.sh --census    one row per registered rule doc
#
# Reports the enforcement shape of the docs/ rule tier: how many normative
# clauses a document carries, and how many of those are machine-checked
# (DETERMINISTIC), agent-judged (JUDGMENT), acknowledged prose (UNENFORCED), or
# untriaged (untagged). Counts INFORM and never fail the build. The only census
# failure is STRUCTURAL: a rule doc cited by a dispatch façade that appears in
# neither the registry nor the exclusion list, or a registered path missing from
# disk — both mean the ledger is lying about coverage.
#
# Exit: 0 clean · 1 structural violation · 2 usage error. Writes nothing.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=audits/rule-ledger-lib.sh
source "$HERE/rule-ledger-lib.sh"

MODE=""
for arg in "$@"; do
  case "$arg" in
    --census) MODE="census" ;;
    -h|--help) printf 'usage: %s --census\n' "$0"; exit 0 ;;
    *) printf 'unknown arg: %s\n' "$arg" >&2; exit 2 ;;
  esac
done
[ -n "$MODE" ] || { printf 'usage: %s --census\n' "$0" >&2; exit 2; }

if [[ -t 1 ]]; then G=$'\033[32m'; R=$'\033[31m'; BO=$'\033[1m'; X=$'\033[0m'
else G=''; R=''; BO=''; X=''; fi
RC=0
fail() { printf '  %s🔴 %s%s\n' "$R" "$1" "$X" >&2; RC=1; }
okln() { printf '  %s🟢%s %s\n' "$G" "$X" "$1"; }

# One machine-parseable row per registered document. Field order is stable and
# every value is a bare integer, so a caller greps `untagged=0` rather than
# parsing a table.
census_row() {
  local doc="$1"
  local path clauses det judgment unenforced tagged untagged
  path="$LEDGER_ROOT/$doc"
  if [ ! -f "$path" ]; then
    fail "doc=$doc MISSING from disk — registered in rule-ledger-lib.sh REGISTERED_DOCS"
    return
  fi
  clauses="$(ledger_count "$path" "$NORMATIVE_PATTERN")"
  det="$(ledger_count "$path" "$DETERMINISTIC_TAG")"
  judgment="$(ledger_count "$path" "$JUDGMENT_TAG")"
  unenforced="$(ledger_count "$path" "$UNENFORCED_TAG")"
  tagged="$(ledger_tagged_total "$path")"
  untagged=$(( clauses - tagged ))
  [ "$untagged" -lt 0 ] && untagged=0
  printf '  doc=%-44s clauses=%-4s det=%-4s judgment=%-4s unenforced=%-4s untagged=%s\n' \
    "$doc" "$clauses" "$det" "$judgment" "$unenforced" "$untagged"
}

# A façade that tells the agent to read a rule doc the ledger does not know
# about means the scoreboard under-reports the corpus. Either register it or
# declare it a non-rule document — silence is the one outcome not allowed.
check_registry_parity() {
  local doc
  while IFS= read -r doc; do
    [ -n "$doc" ] || continue
    ledger_in_list "$doc" "${REGISTERED_DOCS[@]}" && continue
    ledger_in_list "$doc" "${EXCLUDED_DOCS[@]}" && continue
    ledger_has_prefix "$doc" && continue
    fail "doc=$doc cited by a dispatch façade but in neither REGISTERED_DOCS nor EXCLUDED_DOCS (audits/rule-ledger-lib.sh)"
  done < <(ledger_cited_docs)
}

printf '%sRULE ENFORCEMENT LEDGER — census%s\n' "$BO" "$X"
for entry in "${REGISTERED_DOCS[@]}"; do census_row "$entry"; done
printf '\n%sregistry parity%s\n' "$BO" "$X"
check_registry_parity
[ "$RC" -eq 0 ] && okln "every cited rule doc is registered or explicitly excluded"

exit "$RC"
