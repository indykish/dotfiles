#!/usr/bin/env bash
# rule-paths.sh — residence + reachability checks for the federated rule corpus.
#
# The incident this encodes: an agent in an agentsfleet worktree resolved the
# AGENTS.md row "reads docs/REST_API_DESIGN_GUIDELINES.md" against its own
# repository, found nothing (consumer repos carry no rule copies), and designed
# an HTTP surface from memory instead of the guide. Two invariants close it:
#
#   residence    — dotfiles-resident rule docs are cited through the
#                  ~/Projects/dotfiles/ anchor in every surface an agent reads
#                  from a consumer-repo working directory. AGENTS.md (byte-
#                  capped) instead carries the resolution doctrine, zero
#                  CWD-relative hrefs, and no residence-contradicting rows.
#   reachability — the settings allow-rule Read(~/Projects/dotfiles/**) exists
#                  in the repo template AND the live ~/.claude copy, so the
#                  anchored read never dies on a permission prompt.
#
# Sourced by audits/agents-md.sh (labels: "rule-path residence",
# "rule-path reachability"). Classifier: DOTFILES_RESIDENT in audits/data.sh.
#
#   check_rule_residence <ROOT>     # echoes FAIL lines, returns 0/1
#   check_rule_reachability <ROOT>  # echoes FAIL lines, returns 0/1

# Non-dispatch surfaces read from consumer-repo CWDs; dispatch/*.md is globbed.
RULE_PATH_SURFACES=(
  "docs/TEMPLATE.md"
  "docs/EXECUTE_DOC_READS.md"
  "docs/greptile-learnings/RULES.md"
  "skills/kishore-spec-new/SKILL.md"
)

check_rule_residence() {
  local root="$1" rc=0
  local agents="$root/AGENTS.md"   # separate line: $root must be set before it expands here

  # (a) resolution doctrine present in the rendered rules.
  grep -qF 'Rule paths resolve from `~/Projects/dotfiles/`' "$agents" \
    || { echo "FAIL: resolution doctrine missing from AGENTS.md"; rc=1; }

  # (b) zero CWD-relative markdown hrefs — AGENTS.md is served as
  # ~/.claude/CLAUDE.md, so ](./…) and ](../…) resolve against garbage.
  if grep -qE '\]\((\./|\.\./)' "$agents"; then
    echo "FAIL: AGENTS.md carries $(grep -cE '\]\((\./|\.\./)' "$agents") CWD-relative markdown href(s)"
    rc=1
  fi

  # Resident docs/… names derived from DOTFILES_RESIDENT (single classifier).
  local d names=()
  for d in "${DOTFILES_RESIDENT[@]}"; do
    [[ "$d" == docs/* ]] && names+=("${d#docs/}")
  done

  # (c) no AGENTS.md line may pair a resident doc with "(product repo)" — the
  # misread that sent the M143 agent to the wrong repository.
  local alt
  alt=$(IFS='|'; printf '%s' "${names[*]%.md}")
  if grep -E "docs/(${alt})\.md" "$agents" | grep -qF '(product repo)'; then
    echo "FAIL: AGENTS.md line pairs a dotfiles-resident doc with '(product repo)'"
    rc=1
  fi

  # (d) surfaces without a byte cap anchor every resident reference
  # (self-references exempt: a doc naming itself is unambiguous).
  local f rel n parts falt hits
  for f in "$root"/dispatch/*.md "${RULE_PATH_SURFACES[@]/#/${root}/}"; do
    [[ -f "$f" ]] || continue
    rel="${f#"$root"/}"
    parts=()
    for n in "${names[@]}"; do
      [[ "docs/$n" == "$rel" ]] || parts+=("${n%.md}")
    done
    falt=$(IFS='|'; printf '%s' "${parts[*]}")
    hits=$(LC_ALL=C perl -sne \
      'while (/(?<!dotfiles\/)\bdocs\/(?:$a)\.md/g) { printf "  %s:%d: %s\n", $ARGV, $., $& }' \
      -- -a="$falt" "$f" 2>/dev/null)
    if [[ -n "$hits" ]]; then
      echo "FAIL: unanchored dotfiles-resident ref(s) in $rel:"
      printf '%s\n' "$hits" | head -5
      rc=1
    fi
  done

  return $rc
}

check_rule_reachability() {
  local root="$1" rc=0
  local grant='"Read(~/Projects/dotfiles/**)"'

  grep -qF "$grant" "$root/.claude/settings.json" 2>/dev/null \
    || { echo "FAIL: reachability — repo template .claude/settings.json lacks $grant"; rc=1; }

  # Live copy on this machine (env-overridable for harness tests).
  local live="${ORACLE_LIVE_SETTINGS:-$HOME/.claude/settings.json}"
  if [[ -f "$live" ]]; then
    grep -qF "$grant" "$live" \
      || { echo "FAIL: reachability — live $live lacks $grant (re-run the README settings copy step)"; rc=1; }
  fi

  return $rc
}
