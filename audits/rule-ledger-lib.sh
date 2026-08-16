#!/usr/bin/env bash
# rule-ledger-lib.sh — shared extractors for audits/rule-ledger.sh.
#
# Sourced, never executed. Split from the leaf per dispatch/write_any.md
# §File & Function Length Gate so both stay well under the cap.
#
# The docs/ rule tier is the half of the corpus that dispatch/'s coverage audit
# cannot see: evals/dispatch/coverage.sh globs dispatch/*.md only. This library
# supplies the same kind of extraction for docs/, plus the UNENFORCED class that
# makes "prose nobody checks" a counted number instead of an unknown.

# Rule documents whose enforcement this ledger reports. A docs/*.md cited as a
# rule read by a dispatch façade but absent from BOTH lists is a parity red:
# either it belongs here, or it is not a rule doc and belongs in EXCLUDED.
REGISTERED_DOCS=(
  "docs/LOGGING_STANDARD.md"
  "docs/REST_API_DESIGN_GUIDELINES.md"
  "docs/SCHEMA_CONVENTIONS.md"
  "docs/DOCUMENTATION_RULES.md"
  "docs/LIFECYCLE_PATTERNS.md"
  "docs/CHANGELOG_VOICE.md"
  "docs/VERIFY_TIERS.md"
  "docs/greptile-learnings/RULES.md"
)

# Cited by a façade but deliberately not a rule doc: architecture (describes
# shape, enforces nothing), the spec template (a form, gated by
# audits/spec-template.sh), the trigger index, an output-format reference, and
# product-repo docs that do not exist in this checkout at all.
EXCLUDED_DOCS=(
  "docs/DISPATCH_ARCHITECTURE.md"
  "docs/ORLY_ARCHITECTURE.md"
  "docs/TEMPLATE.md"
  "docs/EXECUTE_DOC_READS.md"
  "docs/HARNESS_VERIFY_OUTPUT.md"
  "docs/AUTH.md"
  "docs/changelog.md"
)

# Prefix-matched exclusions for open-ended trees owned by other repositories.
EXCLUDED_PREFIXES=(
  "docs/architecture/"
)

# A normative clause is a line that binds behaviour. This is a keyword
# heuristic, not a parse: counts INFORM the reader and never gate a build, so a
# keyword inside an example block costs nothing but a slightly high number.
NORMATIVE_PATTERN='\b(MUST|NEVER|ALWAYS|Forbidden|Required|SHALL|Do not|Don.t)\b'

# Markdown table rows are excluded from the clause count. In a rule doc a table
# is usually a field reference — `| ts_ms | u64 | always | ... |` — where the
# keyword is a column VALUE, not an obligation, and counting those makes a
# fully-triaged document look permanently unfinished. Rules stated inside a
# table restate prose stated elsewhere; they are still read, just not counted.
TABLE_ROW_PATTERN='^[[:space:]]*\|'

# Enforcement classes. The first two already exist in dispatch/*.md
# (docs/DISPATCH_ARCHITECTURE.md §6); UNENFORCED is added by this milestone so
# an acknowledged-prose clause is distinguishable from one nobody has triaged.
DETERMINISTIC_TAG='\[DETERMINISTIC → [A-Za-z0-9_:-]+\]'
JUDGMENT_TAG='\[JUDGMENT → [A-Za-z0-9_:-]+\]'
UNENFORCED_TAG='\[UNENFORCED → [^]]+\]'

LEDGER_ROOT="${ORLY_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

# A tag alone on its line (the `> [DETERMINISTIC → FLL]` form dispatch/*.md
# already uses) covers every clause under it until the next heading. A tag at
# the end of a sentence covers that sentence only. Both are needed: a rule doc
# states some rules as a tagged section and others as one-line asides, and
# forcing either shape onto the other would mean editing prose to satisfy a
# counter.
STANDALONE_TAG_PATTERN='^[[:space:]]*>?[[:space:]]*\[(DETERMINISTIC|JUDGMENT|UNENFORCED) → [^]]+\][[:space:]]*$'
HEADING_PATTERN='^#{1,6} '
CLASS_DETERMINISTIC="det"
CLASS_JUDGMENT="judgment"
CLASS_UNENFORCED="unenforced"

# Line numbers of every line in a file matching a pattern, one per line.
ledger_line_numbers() {
  grep -nE "$2" "$1" 2>/dev/null | cut -d: -f1
}

# Clause line numbers: keyword lines that are not table rows. Case-insensitive,
# because a rule reads the same whether the author shouted it or not.
ledger_clause_lines() {
  grep -niE "$NORMATIVE_PATTERN" "$1" 2>/dev/null \
    | grep -vE '^[0-9]+:[[:space:]]*\|' | cut -d: -f1
}

# The five census numbers for one document, space-separated:
#   clauses det judgment unenforced untagged
# Returns 1 without output when the path is absent, so a caller reports the
# missing registration rather than printing zeroes that look like a clean doc.
#
# One pass down the file carrying the section's block tag: a heading clears it,
# a standalone tag sets it, and every clause takes the tag on its own line
# first, the block's second, nothing third. Nothing third is the backlog.
ledger_doc_counts() {
  local path="$1"
  local line total block="" class
  local clauses=0 det=0 judgment=0 unenforced=0 untagged=0
  [ -f "$path" ] || return 1
  local is_heading=() is_clause=() line_class=() standalone=()
  for line in $(ledger_line_numbers "$path" "$HEADING_PATTERN"); do is_heading[$line]=1; done
  for line in $(ledger_clause_lines "$path"); do is_clause[$line]=1; done
  for line in $(ledger_line_numbers "$path" "$STANDALONE_TAG_PATTERN"); do standalone[$line]=1; done
  for line in $(ledger_line_numbers "$path" "$DETERMINISTIC_TAG"); do line_class[$line]="$CLASS_DETERMINISTIC"; done
  for line in $(ledger_line_numbers "$path" "$JUDGMENT_TAG"); do line_class[$line]="$CLASS_JUDGMENT"; done
  for line in $(ledger_line_numbers "$path" "$UNENFORCED_TAG"); do line_class[$line]="$CLASS_UNENFORCED"; done

  total="$(wc -l < "$path" | tr -d ' ')"
  for (( line = 1; line <= total; line++ )); do
    [ -n "${is_heading[$line]:-}" ] && { block=""; continue; }
    [ -n "${standalone[$line]:-}" ] && { block="${line_class[$line]:-}"; continue; }
    [ -n "${is_clause[$line]:-}" ] || continue
    class="${line_class[$line]:-$block}"
    clauses=$(( clauses + 1 ))
    case "$class" in
      "$CLASS_DETERMINISTIC") det=$(( det + 1 )) ;;
      "$CLASS_JUDGMENT") judgment=$(( judgment + 1 )) ;;
      "$CLASS_UNENFORCED") unenforced=$(( unenforced + 1 )) ;;
      *) untagged=$(( untagged + 1 )) ;;
    esac
  done
  printf '%s %s %s %s %s' "$clauses" "$det" "$judgment" "$unenforced" "$untagged"
}

# docs/*.md paths any dispatch façade tells the agent to read. Both the bare
# form and the ~/Projects/dotfiles/-anchored form appear in the corpus, so the
# anchor is stripped before comparison.
ledger_cited_docs() {
  grep -rhoE '(~/Projects/dotfiles/)?docs/[A-Za-z0-9_/-]+\.md' "$LEDGER_ROOT"/dispatch/*.md 2>/dev/null \
    | sed -E 's|^~/Projects/dotfiles/||' \
    | sort -u
}

# Membership test against a registry array passed by name-expansion.
ledger_in_list() {
  local needle="$1"; shift
  local item
  for item in "$@"; do [ "$item" = "$needle" ] && return 0; done
  return 1
}

# True when a cited path sits under a tree another repository owns.
ledger_has_prefix() {
  local doc="$1" prefix
  for prefix in "${EXCLUDED_PREFIXES[@]}"; do
    case "$doc" in "$prefix"*) return 0 ;; esac
  done
  return 1
}

# --- trigger reachability -----------------------------------------------------
#
# A rule fires only when something the agent edits matches its façade's scope.
# The scope is declared exactly once, in the `dispatch_init` line of the
# façade's executable, and the history of the repository says whether that
# scope has met a real file lately. Both halves are extracted here.

# How many commits a fire count replays. Reachability is report-only, so the
# window is a readability choice, never a gate parameter.
DEFAULT_HISTORY_COMMITS=50

# dispatch/lib.sh is the shared sourcing target rather than a façade: it
# declares no scope of its own and must never be read as a glob-less one.
DISPATCH_LIB_BASENAME="lib.sh"

# Paths every façade ignores, mirroring dispatch_resolve_files' --staged filter
# so a fire count reports authored edits and not vendored churn.
HISTORY_EXCLUDE_PATTERN='(^|/)(vendor|third_party|node_modules|\.zig-cache|dist|build|\.next)/'

# The executable façades: dispatch/*.sh minus the shared library.
ledger_facade_scripts() {
  local file
  for file in "$LEDGER_ROOT"/dispatch/*.sh; do
    [ -f "$file" ] || continue
    [ "$(basename "$file")" = "$DISPATCH_LIB_BASENAME" ] && continue
    printf '%s\n' "$file"
  done
}

# The language label a façade announces, e.g. ANY for dispatch/write_any.sh.
ledger_facade_lang() {
  grep -hE '^[[:space:]]*dispatch_init[[:space:]]' "$1" 2>/dev/null \
    | head -1 | grep -oE '"[^"]+"' | head -1 | tr -d '"'
}

# The file globs a façade declares, space-separated. dispatch_init quotes its
# language double and every glob single, so the single-quoted run IS the scope.
# Empty output means the façade declares no scope — the caller reds on that.
ledger_facade_globs() {
  grep -hE '^[[:space:]]*dispatch_init[[:space:]]' "$1" 2>/dev/null \
    | head -1 | grep -oE "'[^']+'" | tr -d "'" | tr '\n' ' '
}

# Every path touched in the last N commits, deduplicated. Merges are skipped so
# a merge commit does not re-count what its parents already reported.
ledger_history_paths() {
  local commits="$1"
  git -C "$LEDGER_ROOT" log --no-merges --name-only --pretty=format: \
      -n "$commits" -- . 2>/dev/null \
    | grep -v '^$' | grep -vE "$HISTORY_EXCLUDE_PATTERN" | sort -u
}

# How many paths on stdin fall inside a glob set. The unquoted `case` pattern
# is the match itself — the same expansion dispatch_resolve_files applies to
# explicit file arguments, so a fire count means what the dispatcher means.
ledger_match_count() {
  local globs="$1" path glob matches=0
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    for glob in $globs; do
      # shellcheck disable=SC2254  # the glob is data; expansion performs the match
      case "$path" in $glob) matches=$((matches + 1)); break ;; esac
    done
  done
  printf '%d' "$matches"
}

# The façade stems whose page cites a rule doc. Substring matching catches both
# the bare and the ~/Projects/dotfiles/-anchored spelling of the same path.
ledger_facades_citing() {
  local doc="$1" page
  for page in "$LEDGER_ROOT"/dispatch/*.md; do
    [ -f "$page" ] || continue
    grep -qF "$doc" "$page" 2>/dev/null && printf '%s\n' "$(basename "$page" .md)"
  done
}

# Whether anything can carry a rule doc into a diff mechanically:
#   mechanical — a citing façade declares a file scope
#   latent     — every citing façade is prose the agent must choose to read
#   uncited    — no façade page names the doc at all
# Tree-only, with no history in it, so the scoreboard stays a pure function of
# the checkout.
TRIGGER_MECHANICAL="mechanical"
TRIGGER_LATENT="latent"
TRIGGER_UNCITED="uncited"

ledger_doc_trigger() {
  local doc="$1" stem script cited=1
  while IFS= read -r stem; do
    [ -n "$stem" ] || continue
    cited=0
    script="$LEDGER_ROOT/dispatch/$stem.sh"
    [ -f "$script" ] || continue
    [ -n "$(ledger_facade_globs "$script")" ] || continue
    printf '%s' "$TRIGGER_MECHANICAL"
    return
  done < <(ledger_facades_citing "$doc")
  [ "$cited" -eq 0 ] && { printf '%s' "$TRIGGER_LATENT"; return; }
  printf '%s' "$TRIGGER_UNCITED"
}

# The citing façade stems as one comma-joined field, or an em dash when none.
ledger_doc_facade_list() {
  local doc="$1" stem stems=""
  while IFS= read -r stem; do
    [ -n "$stem" ] || continue
    stems="${stems:+$stems,}$stem"
  done < <(ledger_facades_citing "$doc")
  printf '%s' "${stems:-—}"
}
