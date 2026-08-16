#!/usr/bin/env bash
# rule-ledger.sh — what each rule document actually enforces.
#
#   audits/rule-ledger.sh --census              one row per registered rule doc
#   audits/rule-ledger.sh --reachability [-n N] fire counts over recent history
#
# Reports the enforcement shape of the docs/ rule tier: how many normative
# clauses a document carries, and how many of those are machine-checked
# (DETERMINISTIC), agent-judged (JUDGMENT), acknowledged prose (UNENFORCED), or
# untriaged (untagged). Counts INFORM and never fail the build. The only census
# failure is STRUCTURAL: a rule doc cited by a dispatch façade that appears in
# neither the registry nor the exclusion list, or a registered path missing from
# disk — both mean the ledger is lying about coverage.
#
# Reachability answers the other half: a rule that reads perfectly still governs
# nothing if its façade's scope never meets a file. Fire counts are advisory —
# a dormant surface is a human call — but a façade that declares no scope at all
# is structural, because nothing it says can ever reach a diff.
#
# Exit: 0 clean · 1 structural violation · 2 usage error. Writes nothing.
set -uo pipefail

# A hook exports GIT_DIR/GIT_INDEX_FILE at the repository it fired in; any git
# a child runs would silently retarget there. The reachability replay shells out
# to git, so the scope dies here, before the library resolves LEDGER_ROOT.
unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE GIT_COMMON_DIR GIT_PREFIX \
      GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=audits/rule-ledger-lib.sh
source "$HERE/rule-ledger-lib.sh"

MODE_CENSUS="census"
MODE_REACHABILITY="reachability"
USAGE="usage: $0 --census | --reachability [-n <commits>]"

MODE=""
HISTORY_COMMITS="$DEFAULT_HISTORY_COMMITS"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --census) MODE="$MODE_CENSUS" ;;
    --reachability) MODE="$MODE_REACHABILITY" ;;
    -n)
      shift
      HISTORY_COMMITS="${1:-}"
      case "$HISTORY_COMMITS" in
        ''|*[!0-9]*|0) printf '%s\n-n takes a positive commit count\n' "$USAGE" >&2; exit 2 ;;
      esac
      ;;
    -h|--help) printf '%s\n' "$USAGE"; exit 0 ;;
    *) printf 'unknown arg: %s\n%s\n' "$1" "$USAGE" >&2; exit 2 ;;
  esac
  shift
done
[ -n "$MODE" ] || { printf '%s\n' "$USAGE" >&2; exit 2; }

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

# Zero fires is a warn, never a red: a dormant surface and a dead trigger look
# identical from here, and only a human can tell them apart.
fire_note() {
  [ "$1" -eq 0 ] && printf '  🟠 no fire in the window'
  return 0
}

# One row per executable façade — the scope it declares, and how often that
# scope met a real file in the window.
reachability_facade_rows() {
  local paths_file="$1"
  local script stem lang globs glob_count fires
  while IFS= read -r script; do
    [ -n "$script" ] || continue
    stem="$(basename "$script" .sh)"
    lang="$(ledger_facade_lang "$script")"
    globs="$(ledger_facade_globs "$script")"
    if [ -z "$globs" ]; then
      fail "facade=$stem declares no dispatch_init scope — dispatch/$stem.sh (nothing it carries can ever fire)"
      continue
    fi
    glob_count="$(printf '%s' "$globs" | wc -w | tr -d ' ')"
    fires="$(ledger_match_count "$globs" < "$paths_file")"
    printf '  facade=%-24s lang=%-5s globs=%-4s fires=%s%s\n' \
      "$stem" "${lang:-?}" "$glob_count" "$fires" "$(fire_note "$fires")"
  done < <(ledger_facade_scripts)
}

# One row per registered rule doc — which façade pages carry it into a diff, and
# the fire count of their scopes. A doc whose façades are all latent (a .md with
# no .sh sibling) has no mechanical trigger at all: the honest report is n/a plus
# a warn, not a zero that would read like a dead scope.
reachability_doc_rows() {
  local paths_file="$1"
  local doc stem stems script globs fires total mechanical
  for doc in "${REGISTERED_DOCS[@]}"; do
    stems=""; total=0; mechanical=0
    while IFS= read -r stem; do
      [ -n "$stem" ] || continue
      stems="${stems:+$stems,}$stem"
      script="$LEDGER_ROOT/dispatch/$stem.sh"
      [ -f "$script" ] || continue
      globs="$(ledger_facade_globs "$script")"
      [ -n "$globs" ] || continue
      fires="$(ledger_match_count "$globs" < "$paths_file")"
      total=$(( total + fires ))
      mechanical=1
    done < <(ledger_facades_citing "$doc")
    if [ -z "$stems" ]; then
      printf '  doc=%-44s facades=%-26s fires=n/a  🟠 cited by no façade page\n' "$doc" "—"
    elif [ "$mechanical" -eq 0 ]; then
      printf '  doc=%-44s facades=%-26s fires=n/a  🟠 latent façade only — no declared scope\n' "$doc" "$stems"
    else
      printf '  doc=%-44s facades=%-26s fires=%s%s\n' "$doc" "$stems" "$total" "$(fire_note "$total")"
    fi
  done
}

run_census() {
  printf '%sRULE ENFORCEMENT LEDGER — census%s\n' "$BO" "$X"
  for entry in "${REGISTERED_DOCS[@]}"; do census_row "$entry"; done
  printf '\n%sregistry parity%s\n' "$BO" "$X"
  check_registry_parity
  [ "$RC" -eq 0 ] && okln "every cited rule doc is registered or explicitly excluded"
  return 0
}

run_reachability() {
  local paths_file total_paths
  paths_file="$(mktemp)"
  trap 'rm -f "$paths_file"' EXIT
  ledger_history_paths "$HISTORY_COMMITS" > "$paths_file"
  total_paths="$(wc -l < "$paths_file" | tr -d ' ')"
  printf '%sRULE ENFORCEMENT LEDGER — trigger reachability (last %s commits, %s paths)%s\n' \
    "$BO" "$HISTORY_COMMITS" "$total_paths" "$X"
  reachability_facade_rows "$paths_file"
  printf '\n%sdelegated rule docs%s\n' "$BO" "$X"
  reachability_doc_rows "$paths_file"
  rm -f "$paths_file"
  trap - EXIT
  return 0
}

case "$MODE" in
  "$MODE_CENSUS") run_census ;;
  "$MODE_REACHABILITY") run_reachability ;;
esac

exit "$RC"
