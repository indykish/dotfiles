# shellcheck shell=bash
# Data tables for audits/agents-md.sh — the expectation lists every
# check asserts against, plus the combined-audit awk program. Split out of
# the main audit (LENGTH GATE: keeps agents-md.sh under the 350-line
# cap; data and logic separate cleanly). Sourced, never executed directly.
#
# Adding a dispatch entry/scenario/rule? Update the matching array HERE; the
# audit's dispatch-parity + named-scenario-parity checks fail loudly if a table
# drifts out of sync with AGENTS.md / dispatch/ / audits/agents-md.md.

# Self-fingerprint — every label here MUST be emitted by a pass/fail call in
# the audit. Deleting a check without updating this list trips the final
# self-fingerprint check. This is the script auditing itself.
EXPECTED_LABELS=(
  "dispatch inventory"
  "trigger surface"
  "override syntax"
  "always-forbidden list"
  "skill-chain ordering"
  "HARNESS VERIFY coverage"
  "cross-references"
  "audit fixture: dirty diff"
  "audit fixture: clean diff"
  "dispatch parity"
  "audits/agents-md.md present"
  "lifecycle stages"
  "named scenarios"
  "hook triggers"
  "rule extension protocol"
  "identity handles"
  "memory discipline"
  "size"
)

# Check 1 (dispatch inventory) + check 9b (dispatch parity) — dispatch
# entries that replaced the 20 dissolved gate cards. Source of truth for both
# the inventory loop in agents-md.sh and check_dispatch_parity
# (audits/parity-dispatch.sh). Each name has a dispatch/<name>.md and a row in
# the AGENTS.md dispatch table (entry name in the 2nd column). Keep 1:1 with
# dispatch/*.md.
REQUIRED_DISPATCH=(
  "write_zig" "write_ts_adhere_bun" "write_sql" "write_any"
  "write_spec" "write_http" "write_auth" "write_changelog"
  "write_documentation" "verify" "name_architecture" "edit_rules"
)

# Check 2 — every source/config language has at least one mention.
EXTS=( ".zig" ".ts" ".tsx" ".js" ".jsx" ".py" ".rs" ".go" ".sh" ".sql" )

# Check 4 — the six hard bans must remain.
FORBIDDEN_KEYS=(
  "no-verify"               # hooks/signing
  "Plaintext secrets"       # entity tables
  "Static strings in SQL"   # schema literals
  "Resolving/printing credentials"
  "Force-push default"
  "core paths"              # install-process launches in core paths
)

# Check 6 — every gate's keyword appears in the HARNESS VERIFY verdict block.
HARNESS_KEYS=(
  "FILE SHAPE" "PUB GATE" "LENGTH GATE" "MILESTONE-ID GATE"
  "ZIG GATE" "UI GATE" "DESIGN TOKEN GATE"
  "SCHEMA GUARD" "GREPTILE GATE"
  "Architecture consult"
)

# Check 7 — dotfiles-resident docs + dispatch façades referenced by AGENTS.md
# must exist on disk. The per-language Zig/Bun standards docs were dropped —
# dissolved into dispatch/write_zig.md and dispatch/write_ts_adhere_bun.md
# respectively. The dispatch façades are listed so the AGENTS.md dispatch-table
# refs are checked.
DOTFILES_RESIDENT=(
  "docs/TEMPLATE.md"
  "docs/REST_API_DESIGN_GUIDELINES.md"
  "docs/LOGGING_STANDARD.md"
  "docs/LIFECYCLE_PATTERNS.md"
  "docs/DOCUMENTATION_RULES.md"
  "docs/greptile-learnings/RULES.md"
  "dispatch/write_zig.md"
  "dispatch/write_ts_adhere_bun.md"
  "dispatch/write_sql.md"
  "dispatch/write_any.md"
  "dispatch/write_spec.md"
  "dispatch/write_http.md"
  "dispatch/write_auth.md"
  "dispatch/write_changelog.md"
  "dispatch/write_documentation.md"
  "dispatch/verify.md"
  "dispatch/name_architecture.md"
  "dispatch/edit_rules.md"
)

# Check 11 — every lifecycle stage header is present in AGENTS.md.
LIFECYCLE_HEADERS=(
  "### CHORE (open)"
  "### PLAN"
  "### EXECUTE"
  "### HARNESS VERIFY"
  "### VERIFY"
  "### DOCUMENT"
  "### COMMIT"
  "### CHORE (close)"
)

# Check 12 — each scenario must exist by keyword; array size must equal the
# actual scenario count (parity). Keep this list 1:1 with audits/agents-md.md.
NAMED_SCENARIOS=(
  "New spec"                 # Scenario 1
  "Brainstorming"            # Scenario 2
  "human spots and steers"   # Scenario 3
  "UI"                       # Scenario 4 (covers UI/Zig/TS/JS/shell/CI)
  "Handover"                 # Scenario 5
  "Verification lifecycle"   # Scenario 6
  "kishore-babysit-prs"      # Scenario 7
  "/write-unit-test"         # Scenario 8
  "Hot-fix"                  # Scenario 9
  "Dotfiles"                 # Scenario 10
  "Schema"                   # Scenario 11
  "Auto-mode boundary"       # Scenario 12
  "Invariance Suite"         # Scenario 13
  "Communication"            # Scenario 14
  "Architecture-edit"        # Scenario 15
  "Credentials"              # Scenario 16
  "DB discipline"            # Scenario 17
  "worktree isolation"       # Scenario 18
  "combined audit"           # Scenario 19
  "Rule extension protocol"  # Scenario 20
  "Gate-flag triage"         # Scenario 21
  "Pre-commit audit scope"   # Scenario 22
  "Agent comprehension"      # Scenario 23
  "Memory routing"           # Scenario 24
  "Allocator & concurrency discipline"  # Scenario 25
)

# Check 14 — the Rule-extension protocol must enumerate all four wiring steps.
RULE_EXTENSION_STEPS=( "doc-reads" "audits/agents-md.md" "DOTFILES_RESIDENT" "make audit" )

# Check 8 — combined-audit smoke: flags MS-ID / PUB / UI violations in a diff.
read -r -d '' AWK_PROG <<'AWKEOF' || true
/^\+\+\+ b\// { f=$2; sub("^b/","",f); next }
/^\+/ {
  if (f ~ /\.(zig|sql|ts|tsx|js|jsx|py|rs|go|sh|toml|yaml|json)$/ && f !~ /^(docs|node_modules|vendor|third_party)\//) {
    if (match($0, /M[0-9]+_[0-9]+|§[0-9]+(\.[0-9]+)+|\bT[0-9]+\b|\bdim [0-9]+\.[0-9]+\b/)) print "MS-ID:" f
  }
  if (f ~ /\.zig$/ && $0 ~ /^\+(pub | *pub fn | *[A-Z][a-zA-Z]+,$)/) print "PUB:" f
  if (f ~ /^ui\/packages\/app\/.*\.(tsx|jsx)$/ && $0 ~ /<(section|button|input|dialog|article|nav|header|form)\b/) print "UI:" f
}
AWKEOF
