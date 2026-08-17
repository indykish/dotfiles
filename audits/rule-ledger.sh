#!/usr/bin/env bash
# rule-ledger.sh — what each rule document actually enforces.
#
#   audits/rule-ledger.sh --census        one row per registered rule doc
#
# Reports the enforcement shape of the docs/ rule tier: how many normative
# clauses a document carries, and how many of those are machine-checked
# (DETERMINISTIC), agent-judged (JUDGMENT), acknowledged prose (UNENFORCED), or
# untriaged (untagged). Counts INFORM and never fail the build. The only census
# failure is STRUCTURAL: a rule doc cited by a dispatch façade that appears in
# neither the registry nor the exclusion list, or a registered path missing from
# disk — both mean the ledger is lying about coverage.
#
# The census answers the other half too: a rule that reads perfectly still
# governs nothing if its façade declares no scope, because nothing it says can
# ever reach a diff. That is structural, and answerable from the tree.
#
# Exit: 0 clean · 1 structural violation · 2 usage error. Writes nothing.
set -uo pipefail

# `sort` orders by locale, and this script's output is byte-compared by
# `make audit`. Without a pinned collation the scoreboard is a function of the
# tree AND the contributor's LC_ALL: `LC_ALL=C` sorts `A-Z B-X a_y`, en_US.UTF-8
# sorts `a_y A-Z B-X`. Invisible while every document carries one code, and a
# guaranteed spurious red the moment one carries two.
export LC_ALL=C

# A hook exports GIT_DIR/GIT_INDEX_FILE at the repository it fired in; any git
# a child runs would silently retarget there. The library resolves LEDGER_ROOT
# with git, so the scope dies here, before it is sourced.
unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE GIT_COMMON_DIR GIT_PREFIX \
      GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=audits/rule-ledger-lib.sh
source "$HERE/rule-ledger-lib.sh"

MODE_CENSUS="census"
MODE_WRITE="write"
MODE_CHECK="check"
SCOREBOARD_PATH="docs/RULE_ENFORCEMENT.md"
SCOREBOARD_FIX_COMMAND="bash audits/rule-ledger.sh --write $SCOREBOARD_PATH"
USAGE="usage: $0 --census | --write <file> | --check"

MODE=""
WRITE_TARGET=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --census) MODE="$MODE_CENSUS" ;;
    --check) MODE="$MODE_CHECK" ;;
    --write)
      shift
      WRITE_TARGET="${1:-}"
      [ -n "$WRITE_TARGET" ] || { printf '%s\n--write takes a target file\n' "$USAGE" >&2; exit 2; }
      MODE="$MODE_WRITE"
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

# A façade executable that declares no `dispatch_init` scope carries rules no
# diff can ever reach. It is the one trigger question worth failing on, and it
# is answerable from the tree — unlike "has this fired lately", which depends on
# what happened to get committed recently and gates nothing.
check_facade_scopes() {
  local script stem
  while IFS= read -r script; do
    [ -n "$script" ] || continue
    [ -n "$(ledger_facade_globs "$script")" ] && continue
    stem="$(basename "$script" .sh)"
    fail "facade=$stem declares no dispatch_init scope — dispatch/$stem.sh (nothing it carries can ever fire)"
  done < <(ledger_facade_scripts)
}

run_census() {
  printf '%sRULE ENFORCEMENT LEDGER — census%s\n' "$BO" "$X"
  for entry in "${REGISTERED_DOCS[@]}"; do census_row "$entry"; done
  printf '\n%sstructural checks%s\n' "$BO" "$X"
  check_registry_parity
  check_facade_scopes
  [ "$RC" -eq 0 ] && okln "every cited rule doc is registered; every façade declares a scope"
  return 0
}

scoreboard_legend() {
  cat <<'LEGEND'
## How to read this

- **enforced by** — the rules in this document a script decides, and the script
  that decides each. This is the column worth acting on: it is the difference
  between a rule that holds and a rule that is merely written down. A code
  reading `no helper row` is a `[DETERMINISTIC → …]` tag with nothing behind it.
- **judged / acknowledged** — clauses an agent must weigh (`[JUDGMENT → CODE]`)
  and clauses nobody checks on purpose (`[UNENFORCED → reason]`, the reason
  stated where a reader meets it).
- **classified** — how much of the document has been triaged at all. The
  denominator counts lines carrying a normative keyword outside headings and
  tables — a keyword heuristic, not a parse. It informs; it never gates.
- **trigger** — `mechanical` when a citing façade declares a file scope,
  `latent` when every citing façade is prose the agent must choose to read,
  `uncited` when no façade names the document at all.

A tag alone on its line covers every clause under it until the next heading; a
tag at the end of a sentence covers that sentence. Same grammar the
`dispatch/*.md` façades use, read by the same code.

Everything here is a function of the tree alone — no timestamps, no commit
hashes, no history — so the file reproduces from a checkout and any diff means
the corpus moved.
LEGEND
}

# The scoreboard body: what each document actually enforces, then how much of it
# has been triaged. Deterministic by construction — registry order in, content
# out — so `--check` can regenerate and byte-compare.
render_scoreboard() {
  local doc counts clauses det judgment unenforced untagged code codes
  local sum_clauses=0 sum_classified=0
  printf '# Rule enforcement ledger\n\n'
  printf 'Generated by `audits/rule-ledger.sh`. Never hand-edit: `make audit`\n'
  printf 'regenerates this file and fails on any difference. To update it, run\n'
  printf '`%s`.\n\n' "$SCOREBOARD_FIX_COMMAND"
  printf '| Rule document | enforced by | judged | acknowledged | classified | trigger |\n'
  printf '|---|---|--:|--:|--:|---|\n'
  for doc in "${REGISTERED_DOCS[@]}"; do
    counts="$(ledger_doc_counts "$LEDGER_ROOT/$doc")" || return 1
    read -r clauses det judgment unenforced untagged <<< "$counts"
    codes=""
    while IFS= read -r code; do
      [ -n "$code" ] || continue
      codes="${codes:+$codes<br>}\`$code\` → \`$(ledger_code_script "$code")\`"
    done < <(ledger_doc_codes "$LEDGER_ROOT/$doc")
    printf '| `%s` | %s | %s | %s | %s/%s | %s |\n' \
      "$doc" "${codes:-—}" "$judgment" "$unenforced" \
      "$(( clauses - untagged ))" "$clauses" "$(ledger_doc_trigger "$doc")"
    sum_clauses=$(( sum_clauses + clauses ))
    sum_classified=$(( sum_classified + clauses - untagged ))
  done
  printf '| **corpus** | | | | **%s/%s** | |\n\n' "$sum_classified" "$sum_clauses"
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
  "$MODE_WRITE") run_write "$WRITE_TARGET" ;;
  "$MODE_CHECK") run_check ;;
esac

exit "$RC"
