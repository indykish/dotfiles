#!/usr/bin/env bash
# evals/ledger/lib.sh — fixture builders and result reporting for run.sh.
#
# Sourced, never executed. Split from the runner so the cases stay readable as
# a list of behaviours: run.sh reads top-to-bottom as "what the ledger must do",
# and the machinery for building throwaway repositories lives here.

REGISTERED=(
  "docs/LOGGING_STANDARD.md" "docs/REST_API_DESIGN_GUIDELINES.md"
  "docs/SCHEMA_CONVENTIONS.md" "docs/DOCUMENTATION_RULES.md"
  "docs/LIFECYCLE_PATTERNS.md" "docs/CHANGELOG_VOICE.md"
  "docs/VERIFY_TIERS.md" "docs/greptile-learnings/RULES.md"
)

if [[ -t 1 ]]; then G=$'\033[32m'; R=$'\033[31m'; BO=$'\033[1m'; X=$'\033[0m'
else G=''; R=''; BO=''; X=''; fi
PASS=0; FAIL=0; SANDBOXES=()
cleanup() { local d; for d in "${SANDBOXES[@]+"${SANDBOXES[@]}"}"; do rm -rf "$d"; done; }
trap cleanup EXIT

ok()   { printf '  %sPASS%s  %s\n' "$G" "$X" "$1"; PASS=$((PASS + 1)); }
bad()  { printf '  %sFAIL%s  %s — %s\n' "$R" "$X" "$1" "$2" >&2; FAIL=$((FAIL + 1)); }

# A fixture root carrying every registered doc, so a case under test is the
# only thing that can turn the census red.
mk_root() {
  local sb; sb="$(mktemp -d)"; SANDBOXES+=("$sb")
  mkdir -p "$sb/dispatch" "$sb/docs/greptile-learnings"
  local doc
  for doc in "${REGISTERED[@]}"; do
    printf '# fixture\n\nThe caller MUST do the thing.\n' > "$sb/$doc"
  done
  printf '# façade\n\nReads `docs/LOGGING_STANDARD.md` first.\n' > "$sb/dispatch/write_fixture.md"
  printf '%s' "$sb"
}

# A façade executable is a file plus one dispatch_init line. Fixtures that need
# a working scope get one; the structural case deliberately omits it.
mk_facade() {
  local root="$1" stem="$2" init="$3"
  printf '#!/usr/bin/env bash\nsource "$(dirname "$0")/lib.sh"\n%s\n' "$init" \
    > "$root/dispatch/$stem.sh"
}

# A fixture repository: the census fixtures, a façade whose scope is '*.sh', and
# one commit, so the check has a real repository to read staged files from.
mk_repo() {
  local sb; sb="$(mk_root)"
  mk_facade "$sb" "write_fixture" "dispatch_init \"FIX\" '*.sh'"
  git -C "$sb" init -q
  git -C "$sb" config user.email "evals@example.invalid"
  git -C "$sb" config user.name "ledger evals"
  git -C "$sb" add -A >/dev/null 2>&1
  git -C "$sb" commit -qm "fixture baseline" >/dev/null 2>&1
  printf '%s' "$sb"
}

run_ledger()   { ORLY_ROOT="$1" bash "$LEDGER" --census 2>&1; }
run_reach()    { ORLY_ROOT="$1" bash "$LEDGER" --reachability 2>&1; }
run_check()    { ORLY_ROOT="$1" bash "$LEDGER" --check 2>&1; }
run_doc_read() { local root="$1"; shift; ORLY_ROOT="$root" bash "$DOC_READ" "$@" 2>&1; }
repo_log()     { printf '%s/.git/orly/doc-reads.jsonl' "$1"; }

# Exit code of a command whose output does not matter — the usage matrix asserts
# codes, and swallowing stderr keeps a deliberate misuse from looking like a
# suite failure in the transcript.
exit_code_of() { "$@" >/dev/null 2>&1; printf '%d' "$?"; }
