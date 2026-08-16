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
MODE_WRITE="write"
MODE_CHECK="check"
SCOREBOARD_PATH="docs/RULE_ENFORCEMENT.md"
SCOREBOARD_FIX_COMMAND="bash audits/rule-ledger.sh --write $SCOREBOARD_PATH"
USAGE="usage: $0 --census | --reachability [-n <commits>] | --write <file> | --check"

MODE=""
WRITE_TARGET=""
HISTORY_COMMITS="$DEFAULT_HISTORY_COMMITS"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --census) MODE="$MODE_CENSUS" ;;
    --reachability) MODE="$MODE_REACHABILITY" ;;
    --check) MODE="$MODE_CHECK" ;;
    --write)
      shift
      WRITE_TARGET="${1:-}"
      [ -n "$WRITE_TARGET" ] || { printf '%s\n--write takes a target file\n' "$USAGE" >&2; exit 2; }
      MODE="$MODE_WRITE"
      ;;
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
  local counts clauses det judgment unenforced untagged
  if ! counts="$(ledger_doc_counts "$LEDGER_ROOT/$doc")"; then
    fail "doc=$doc MISSING from disk — registered in rule-ledger-lib.sh REGISTERED_DOCS"
    return
  fi
  read -r clauses det judgment unenforced untagged <<< "$counts"
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

scoreboard_legend() {
  cat <<'LEGEND'
## How to read this

- **clauses** — lines carrying a normative keyword (MUST / NEVER / ALWAYS /
  Forbidden / Required / SHALL / Do not). A keyword heuristic, not a parse: the
  number informs a reader and never gates a build.
- **deterministic** — clauses tagged `[DETERMINISTIC → CODE]`: a script decides,
  and the agent cannot talk its way past the verdict.
- **judgment** — clauses tagged `[JUDGMENT → CODE]`: only an agent can weigh
  them, so the enforcement is a read plus a proof-line.
- **unenforced** — clauses tagged `[UNENFORCED → reason]`: prose nobody checks,
  acknowledged on purpose rather than pretended away.
- **untagged** — clauses nobody has classified yet. This column is the backlog:
  every row above zero is a document whose real coverage is still unknown.
- **façades** — the `dispatch/` pages that tell an agent to read the document.
- **trigger** — `mechanical` when a citing façade declares a file scope,
  `latent` when every citing façade is prose the agent must choose to read,
  `uncited` when no façade names the document at all.

Fire counts over history are deliberately absent: they are a function of
recent commits rather than of the tree, and this file must stay reproducible
from a checkout alone. Run `bash audits/rule-ledger.sh --reachability` for them.
LEGEND
}

# The scoreboard body. A pure function of the tree — registry order in, counts
# derived from file content, no timestamp and no commit hash — so two runs on
# one checkout are byte-identical and any diff means the corpus moved.
render_scoreboard() {
  local doc counts clauses det judgment unenforced untagged
  local sum_clauses=0 sum_det=0 sum_judgment=0 sum_unenforced=0 sum_untagged=0
  printf '# Rule enforcement ledger\n\n'
  printf 'Generated by `audits/rule-ledger.sh`. Never hand-edit: `make audit`\n'
  printf 'regenerates this file and fails on any difference. To update it, run\n'
  printf '`%s`.\n\n' "$SCOREBOARD_FIX_COMMAND"
  printf '| Rule document | clauses | deterministic | judgment | unenforced | untagged | façades | trigger |\n'
  printf '|---|--:|--:|--:|--:|--:|---|---|\n'
  for doc in "${REGISTERED_DOCS[@]}"; do
    counts="$(ledger_doc_counts "$LEDGER_ROOT/$doc")" || return 1
    read -r clauses det judgment unenforced untagged <<< "$counts"
    printf '| `%s` | %s | %s | %s | %s | %s | %s | %s |\n' \
      "$doc" "$clauses" "$det" "$judgment" "$unenforced" "$untagged" \
      "$(ledger_doc_facade_list "$doc")" "$(ledger_doc_trigger "$doc")"
    sum_clauses=$(( sum_clauses + clauses )); sum_det=$(( sum_det + det ))
    sum_judgment=$(( sum_judgment + judgment ))
    sum_unenforced=$(( sum_unenforced + unenforced ))
    sum_untagged=$(( sum_untagged + untagged ))
  done
  printf '| **corpus** | **%s** | **%s** | **%s** | **%s** | **%s** | | |\n\n' \
    "$sum_clauses" "$sum_det" "$sum_judgment" "$sum_unenforced" "$sum_untagged"
  scoreboard_legend
}

run_write() {
  local target="$1" rendered
  case "$target" in /*) ;; *) target="$LEDGER_ROOT/$target" ;; esac
  rendered="$(mktemp)"
  trap 'rm -f "$rendered"' EXIT
  if render_scoreboard > "$rendered"; then
    cat "$rendered" > "$target"
    printf 'wrote %s\n' "$target"
  else
    fail "render aborted — a registered doc is missing from disk; run --census for the name"
  fi
  rm -f "$rendered"
  trap - EXIT
  return 0
}

# Currency, not content: the committed file must equal what this tree renders.
# A stale scoreboard is a red because a wrong number read as fact is worse than
# no number at all.
run_check() {
  local target="$LEDGER_ROOT/$SCOREBOARD_PATH" rendered
  rendered="$(mktemp)"
  trap 'rm -f "$rendered"' EXIT
  printf '%sRULE ENFORCEMENT LEDGER — scoreboard currency%s\n' "$BO" "$X"
  if ! render_scoreboard > "$rendered"; then
    fail "a registered doc is missing from disk — run --census for the name"
  elif [ ! -f "$target" ]; then
    fail "$SCOREBOARD_PATH does not exist — regenerate: $SCOREBOARD_FIX_COMMAND"
  elif ! cmp -s "$rendered" "$target"; then
    fail "$SCOREBOARD_PATH is stale — regenerate: $SCOREBOARD_FIX_COMMAND"
  else
    okln "$SCOREBOARD_PATH matches the tree"
  fi
  rm -f "$rendered"
  trap - EXIT
  return 0
}

case "$MODE" in
  "$MODE_CENSUS") run_census ;;
  "$MODE_REACHABILITY") run_reachability ;;
  "$MODE_WRITE") run_write "$WRITE_TARGET" ;;
  "$MODE_CHECK") run_check ;;
esac

exit "$RC"
