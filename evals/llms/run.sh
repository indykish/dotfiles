#!/usr/bin/env bash
# Cross-agent Large Language Model (LLM) evaluation for AGENTS.md
# (audits/agents-md.md Scenario 23). The deterministic audit proves the
# rules are PRESENT; it can't prove an agent READING them complies — the
# hallucination class. This closes that gap: a frozen golden-set of
# question→expected-verdict fixtures is answered by EACH installed agent
# (claude, codex, amp, opencode), graded by exact match. Disagreement = an
# ambiguous rule (doc bug) or a model that won't comply. The full ruleset
# (AGENTS.md + gate bodies) is embedded in every prompt — no tool use, no
# file-read variance — and only the single `VERDICT: YES|NO` line is graded.
#
# Modes: --check (validate fixtures + availability, no live calls) · --smoke
# (fixed first fixture, once per agent) · --agent <name> · --ids <csv> (run
# only the named fixtures — a targeted demonstration; no journal) ·
# --threshold <N> (default 100) · --fresh (ignore journal) · (default) full
# set × every agent. In the FULL graded run an absent or credit-blocked agent
# FAILS the gate — "every agent adheres" cannot be proven by an agent that
# never answered; smoke stays lenient (plumbing check, logged + excluded).
#
# Per-fixture context: a fixture may carry "ctx": [paths] — the prompt then
# embeds AGENTS.md + only those files ([] = AGENTS.md alone). Absent ctx =
# the full façade embed (backward compatible).

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
AGENTS="$ROOT/AGENTS.md"
DISPATCH_DIR="$ROOT/dispatch"
FIXTURES="$ROOT/evals/llms/fixtures.jsonl"
JOURNAL_DIR="$ROOT/.llmevals-journal"
CALL_TIMEOUT="${LLMEVALS_TIMEOUT:-${COMPREHENSION_TIMEOUT:-180}}"

MODE="full"; ONLY_AGENT=""; ONLY_IDS=""; THRESHOLD=100; FRESH=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)     MODE="check" ;;
    --smoke)     MODE="smoke" ;;
    --agent)     ONLY_AGENT="${2:-}"; shift ;;
    --ids)       ONLY_IDS="${2:-}"; shift ;;
    --threshold) THRESHOLD="${2:-100}"; shift ;;
    --fresh)     FRESH=1 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

if [[ -t 1 ]]; then
  G=$'\033[32m'; R=$'\033[31m'; Y=$'\033[33m'; B=$'\033[34m'; BO=$'\033[1m'; X=$'\033[0m'
else G=''; R=''; Y=''; B=''; BO=''; X=''; fi

AGENTS_ALL=(claude codex amp opencode)
have() { command -v "$1" >/dev/null 2>&1; }

# Agent I/O and fixture loading live in siblings (FLL split, dispatch/write_any.md
# §File & Function Length Gate). Located from this file rather than rebuilt from
# ROOT, so moving or renaming the tree cannot desynchronise the three. Sourced
# AFTER the variables above are set — they read ROOT, AGENTS, DISPATCH_DIR,
# CTX_FILE, FIXTURES, CALL_TIMEOUT, AGENTS_ALL and have().
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/agents.sh"
source "$HERE/fixtures.sh"

# ---------------------------------------------------------------------------
printf '%s🧠 AGENTS.md cross-agent Large Language Model (LLM) evaluation%s  (mode=%s threshold=%s%%)\n\n' "$B$BO" "$X" "$MODE" "$THRESHOLD"

[[ -f "$FIXTURES" ]] || { echo "${R}FAIL${X}: fixtures missing: $FIXTURES" >&2; exit 2; }
validate_fixtures || { echo "${R}FAIL${X}: fixture validation failed" >&2; exit 2; }

mapfile -t AVAIL < <(list_available)
echo "Agents available: ${AVAIL[*]:-(none)}"
for a in "${AGENTS_ALL[@]}"; do
  have "$a" || echo "${Y}  skip${X}: $a not installed (logged, not silently dropped)"
done

if [[ "$MODE" == "check" ]]; then
  echo; echo "${G}✓ check mode${X}: fixtures valid, availability reported. No live calls made."
  exit 0
fi

[[ ${#AVAIL[@]} -gt 0 ]] || { echo "${R}FAIL${X}: no agent CLIs available to run" >&2; exit 2; }

# Build context once.
CTX_FILE="$(mktemp)"; build_context > "$CTX_FILE"
trap 'rm -f "$CTX_FILE"' EXIT

# Determine target agents + fixture subset.
TARGETS=("${AVAIL[@]}")
[[ -n "$ONLY_AGENT" ]] && TARGETS=("$ONLY_AGENT")

mapfile -t IDS    < <(fixtures_field id     | cut -f1)
declare -A EXPECT QTEXT CTXS
while IFS=$'\t' read -r id v; do EXPECT["$id"]="$v"; done < <(fixtures_field expect)
while IFS=$'\t' read -r id v; do QTEXT["$id"]="$v";  done < <(fixtures_field q)
while IFS=$'\t' read -r id v; do CTXS["$id"]="$v";   done < <(fixtures_ctx)

[[ "$MODE" == "smoke" ]] && IDS=("${IDS[0]}")

# --ids: a targeted subset (demonstration / regression probe). Unknown ids are
# a hard error — a typo must not silently shrink the run. No journal: only the
# untouched full set may claim a completed graded run.
if [[ -n "$ONLY_IDS" ]]; then
  SUBSET=()
  IFS=',' read -ra WANT <<< "$ONLY_IDS"
  for w in "${WANT[@]}"; do
    [[ -n "${EXPECT[$w]:-}" ]] || { echo "${R}FAIL${X}: unknown fixture id: $w" >&2; exit 2; }
    SUBSET+=("$w")
  done
  IDS=("${SUBSET[@]}")
fi

# Resumability — a long live run can be killed (session restart, Ctrl-C). Each
# agent's verdict is journalled the moment it completes, keyed to HEAD + the
# fixtures hash, so a re-run skips finished agents instead of re-spending tokens.
# A drifted ruleset/fixtures changes RUNKEY → stale journal is ignored. --fresh
# forces a clean run. Journal is gitignored and machine-local.
HEAD_SHA="$(cd "$ROOT" && git rev-parse --short HEAD 2>/dev/null || echo nogit)"
FIX_HASH="$( (md5 -q "$FIXTURES" 2>/dev/null || md5sum "$FIXTURES" 2>/dev/null | cut -d' ' -f1) )"
RUNKEY="${HEAD_SHA}-${FIX_HASH}-t${THRESHOLD}"
RUN_JDIR="$JOURNAL_DIR/$RUNKEY"
[[ "$MODE" == "full" && -z "$ONLY_IDS" ]] || RUN_JDIR=""  # journal only for full graded runs
[[ $FRESH -eq 1 && -n "$RUN_JDIR" ]] && rm -rf "$RUN_JDIR"
[[ -n "$RUN_JDIR" ]] && mkdir -p "$RUN_JDIR"

OVERALL_OK=1; GRADED=0
REPORT=""; UNAVAIL=""

for agent in "${TARGETS[@]}"; do
  have "$agent" || { echo "${R}requested agent absent: $agent${X}"; OVERALL_OK=0; continue; }
  # Resume: a journalled result for this agent at this RUNKEY is replayed.
  jf="${RUN_JDIR:+$RUN_JDIR/$agent}"
  if [[ -n "$jf" && -f "$jf" ]]; then
    read -r jstatus jcorrect jtotal < "$jf"
    echo; echo "${BO}── $agent ──${X} ${B}(resumed from journal)${X}"
    case "$jstatus" in
      UNAVAIL) UNAVAIL="$UNAVAIL $agent"; REPORT="$REPORT$agent=UNAVAIL "
               echo "  ${Y}⚠ unavailable${X} (journalled)" ;;
      *) GRADED=$((GRADED + 1)); REPORT="$REPORT$agent=$jcorrect/$jtotal "
         [[ "$jstatus" == PASS ]] && echo "  ${G}→ $jcorrect/$jtotal PASS (journalled)${X}" \
           || { echo "  ${R}→ $jcorrect/$jtotal FAIL (journalled)${X}"; OVERALL_OK=0; } ;;
    esac
    continue
  fi
  echo; echo "${BO}── $agent ──${X}"
  correct=0; total=0; fails=""; unavailable=0
  for id in "${IDS[@]}"; do
    pf="$(mktemp)"; out="$(mktemp)"
    build_prompt "${QTEXT[$id]}" "${CTXS[$id]:-__FULL__}" > "$pf"
    invoke_agent "$agent" "$pf" "$out"
    # An availability/credit/auth error means this agent can't run headless —
    # log + exclude from the gate (don't score it 0 and sink the suite).
    if is_unavailable "$out"; then
      unavailable=1; rm -f "$pf" "$out"
      printf '  %s⚠ unavailable%s: %s emitted a credit/auth/quota error — excluded from gate\n' "$Y" "$X" "$agent"
      break
    fi
    total=$((total+1))
    got="$(extract_verdict "$out")"; got="${got:-?}"; rm -f "$pf" "$out"
    want="${EXPECT[$id]}"
    if [[ "$got" == "$want" ]]; then
      correct=$((correct+1)); printf '  %s✓%s %-34s %s\n' "$G" "$X" "$id" "$got"
    else
      printf '  %s✗%s %-34s got=%s want=%s\n' "$R" "$X" "$id" "$got" "$want"
      fails="$fails ${id}(${got}-vs-${want})"
    fi
  done
  if [[ $unavailable -eq 1 ]]; then
    UNAVAIL="$UNAVAIL $agent"; REPORT="$REPORT$agent=UNAVAIL "
    [[ -n "$jf" ]] && echo "UNAVAIL 0 0" > "$jf"
    continue
  fi
  GRADED=$((GRADED + 1))
  pct=$(( correct * 100 / total ))
  if [[ $pct -ge $THRESHOLD ]]; then
    printf '  %s→ %d/%d = %d%% PASS%s\n' "$G" "$correct" "$total" "$pct" "$X"
    [[ -n "$jf" ]] && echo "PASS $correct $total" > "$jf"
  else
    printf '  %s→ %d/%d = %d%% FAIL (below %d%%)%s\n' "$R" "$correct" "$total" "$pct" "$THRESHOLD" "$X"
    [[ -n "$fails" ]] && echo "    misses:$fails"
    OVERALL_OK=0
    [[ -n "$jf" ]] && echo "FAIL $correct $total" > "$jf"
  fi
  REPORT="$REPORT$agent=$correct/$total "
done
if [[ -n "$UNAVAIL" ]]; then
  echo
  if [[ "$MODE" == "full" ]]; then
    # "Every agent adheres" cannot be proven by an agent that never answered:
    # in the graded run, unavailability FAILS the gate instead of shrinking it.
    echo "${R}Unavailable agent(s) fail the full gate:${X}$UNAVAIL — restore auth/credits, or run --agent for a partial look"
    OVERALL_OK=0
  else
    echo "${Y}Unavailable (excluded from smoke):${X}$UNAVAIL"
  fi
fi

echo; echo "${BO}Summary:${X} $REPORT"

if [[ "$MODE" == "smoke" ]]; then
  echo "${Y}smoke mode${X}: plumbing validated."
  [[ $OVERALL_OK -eq 1 ]] && exit 0 || exit 1
fi

if [[ "$MODE" == "full" && -z "$ONLY_AGENT" && -z "$ONLY_IDS" && $OVERALL_OK -eq 1 ]]; then
  if [[ $GRADED -eq 0 ]]; then
    echo "${R}🔴 no agent could be graded; all were unavailable${X}"
    exit 1
  fi
  echo "${G}✅ live comprehension passed${X}: graded=$GRADED $REPORT"
  [[ -n "$RUN_JDIR" ]] && rm -rf "$RUN_JDIR"   # run complete — clear its journal
  exit 0
fi

[[ $OVERALL_OK -eq 1 ]] && exit 0 || { echo "${R}🔴 LLM-eval below threshold — see misses${X}"; exit 1; }
