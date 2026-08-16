#!/usr/bin/env bash
# rule-paths.sh — residence + reachability checks for the federated rule corpus.
#
# The incident this encodes (M143): an agent in an agentsfleet worktree
# resolved "reads docs/REST_API_DESIGN_GUIDELINES.md" against its own
# repository, found nothing — under the old thin-distribution model, consumer
# repos carried no rule copies at all — and designed an HTTP surface from
# memory instead of the guide.
#
# M03_001 closed that gap by materialising rule docs into every consuming
# repository (`orly init`/`orly update`, keyed by the profile's selected
# packs). A citation now resolving to a real local file IS the fix, so the
# invariant inverts: the ~/Projects/dotfiles/ anchor becomes wrong wherever
# it appears in a surface a materialised repository also carries — it names a
# path that will not exist on any machine but this one.
#
#   residence    — dotfiles-resident rule docs are cited relative to the
#                  installing repository, never through the
#                  ~/Projects/dotfiles/ anchor, in every surface `orly init`
#                  materialises. AGENTS.md (byte-capped) carries the new
#                  resolution doctrine, zero CWD-relative hrefs, and no
#                  residence-contradicting rows. Files that never leave this
#                  checkout (RULE_PATH_ENGINE_ONLY — governance-editing
#                  façades genuinely about the engine's own source) are
#                  exempt; their absolute citations are correct.
#   reachability — the settings allow-rule Read(~/Projects/dotfiles/**) exists
#                  in the repo template AND the live ~/.claude copy, so
#                  Kishore's own machine-level tooling (skills, the
#                  governance-editing workflow) never dies on a permission
#                  prompt. Unrelated to residence: reachability is about this
#                  machine, residence is about what a materialised repository
#                  carries.
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
)

# Governance-editing façades describe how to edit THIS engine's own source
# (orly/**, the registry, the rendered AGENTS.md) — a workflow that only ever
# runs inside this checkout. Their absolute citations are correct, not a
# residual of the old model; a materialised copy would never satisfy them
# because there is nothing to materialise (a consumer never receives
# orly/core/, orly/registry.json, or this checkout's own dispatch/edit_rules.md).
RULE_PATH_ENGINE_ONLY=(
  "dispatch/edit_rules.md"
)

check_rule_residence() {
  local root="$1" rc=0
  local agents="$root/AGENTS.md"   # separate line: $root must be set before it expands here

  # (a) resolution doctrine present in the rendered rules.
  grep -qF 'Rule paths resolve relative to this repository' "$agents" \
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
  # misread that sent the M143 agent to the wrong repository. Still a real
  # mistake under the new model: a doc this array names IS materialised here.
  local alt
  alt=$(IFS='|'; printf '%s' "${names[*]%.md}")
  if grep -E "docs/(${alt})\.md" "$agents" | grep -qF '(product repo)'; then
    echo "FAIL: AGENTS.md line pairs a dotfiles-resident doc with '(product repo)'"
    rc=1
  fi

  # (d) surfaces materialised by orly init must cite resident docs relative to
  # the installing repository — never through the ~/Projects/dotfiles/ anchor,
  # which names a path absent on every machine but this one. Engine-only
  # façades (RULE_PATH_ENGINE_ONLY) are exempt: their absolute citations are
  # correct because nothing is ever materialised to satisfy them.
  local f rel is_exempt e hits
  for f in "$agents" "$root"/dispatch/*.md "${RULE_PATH_SURFACES[@]/#/${root}/}"; do
    [[ -f "$f" ]] || continue
    rel="${f#"$root"/}"
    is_exempt=0
    for e in "${RULE_PATH_ENGINE_ONLY[@]}"; do [[ "$e" == "$rel" ]] && is_exempt=1; done
    [[ "$is_exempt" -eq 1 ]] && continue
    hits=$(LC_ALL=C grep -noE '~/Projects/dotfiles/(docs|dispatch|audits)/[A-Za-z0-9_./-]+\.(md|sh)' "$f" | head -5)
    if [[ -n "$hits" ]]; then
      echo "FAIL: anchored citation in $rel (should resolve relative to the installing repository):"
      printf '  %s\n' "$hits"
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
