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

# Enforcement classes. The first two already exist in dispatch/*.md
# (docs/DISPATCH_ARCHITECTURE.md §6); UNENFORCED is added by this milestone so
# an acknowledged-prose clause is distinguishable from one nobody has triaged.
DETERMINISTIC_TAG='\[DETERMINISTIC → [A-Za-z0-9_:-]+\]'
JUDGMENT_TAG='\[JUDGMENT → [A-Za-z0-9_:-]+\]'
UNENFORCED_TAG='\[UNENFORCED → [^]]+\]'

LEDGER_ROOT="${ORLY_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

# Count lines matching a pattern in a file; 0 when the file is absent so a
# caller can report a missing path rather than dying on it.
ledger_count() {
  local file="$1" pattern="$2"
  local n
  [ -f "$file" ] || { printf '0'; return; }
  # grep -c exits 1 on zero matches; capture first, then normalise, so a
  # legitimate zero never concatenates with a fallback.
  n="$(grep -ciE "$pattern" "$file" 2>/dev/null | tr -d ' \n')"
  printf '%s' "${n:-0}"
}

# Every tagged clause in a file, by class.
ledger_tagged_total() {
  local file="$1"
  local n
  [ -f "$file" ] || { printf '0'; return; }
  n="$(grep -oE "$DETERMINISTIC_TAG|$JUDGMENT_TAG|$UNENFORCED_TAG" "$file" 2>/dev/null | wc -l | tr -d ' \n')"
  printf '%s' "${n:-0}"
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
