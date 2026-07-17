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
# (fixed first fixture, once per agent) · --agent <name> · --threshold <N>
# (default 100) ·
# --fresh (ignore journal) · (default) full set × every agent. The command exits
# successfully when every gradable agent meets the threshold; absent or
# credit-blocked agents are logged, never silently skipped.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
AGENTS="$ROOT/AGENTS.md"
DISPATCH_DIR="$ROOT/dispatch"
FIXTURES="$ROOT/evals/llms/fixtures.jsonl"
JOURNAL_DIR="$ROOT/.llmevals-journal"
CALL_TIMEOUT="${LLMEVALS_TIMEOUT:-${COMPREHENSION_TIMEOUT:-180}}"

MODE="full"; ONLY_AGENT=""; THRESHOLD=100; FRESH=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)     MODE="check" ;;
    --smoke)     MODE="smoke" ;;
    --agent)     ONLY_AGENT="${2:-}"; shift ;;
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

# Agent invocation — per-agent because their headless I/O differs. Each takes
# ($1=prompt_file, $2=answer_out_file) and must land the agent's reply text in
# answer_out_file. Most stream to stdout; codex needs --output-last-message
# (its stdout is event noise that drowns the VERDICT line). Wrapped in a
# portable timeout so a hung agent can't stall the suite. Add a case to extend.
invoke_agent() {
  local agent="$1" prompt="$2" out="$3" secs="$CALL_TIMEOUT"
  : >"$out"
  case "$agent" in
    # Each agent's headless I/O differs — established empirically:
    #   claude   : prompt on stdin, -p.
    #   codex    : prompt on stdin; stdout is event noise, so the answer is
    #              captured via --output-last-message.
    #   amp      : prompt on stdin with the LONG --execute form (the short
    #              `-x` and the positional-arg form both misbehave here).
    #   opencode : prompt as a positional ARG to `run` (default format; its
    #              `--format` only accepts default|json). ~100 KB << ARG_MAX.
    # amp/opencode stdout carries ANSI/control bytes — extract_verdict strips
    # them before matching. stderr is captured INTO $out (2>>) so credit/auth
    # errors (e.g. amp's 402) are visible to is_unavailable — otherwise a
    # blocked agent looks like a wrong "?" answer instead of unavailable.
    claude)   ( timeout "$secs" claude -p < "$prompt" >"$out" 2>>"$out" ) ;;
    amp)      ( timeout "$secs" amp --execute < "$prompt" >"$out" 2>>"$out" ) ;;
    opencode) ( timeout "$secs" opencode run "$(cat "$prompt")" >"$out" 2>>"$out" ) ;;
    # codex: answer lands in $msg via --output-last-message; event noise + any
    # error text go to $out so is_unavailable can see them; then the clean
    # answer is appended (extract_verdict takes the LAST VERDICT line).
    codex)    local msg="$out.msg"
              ( timeout "$secs" codex exec - --skip-git-repo-check \
                  --output-last-message "$msg" < "$prompt" >"$out" 2>>"$out" )
              [[ -f "$msg" ]] && { cat "$msg" >>"$out"; rm -f "$msg"; } ;;
    *) return 127 ;;
  esac
}

build_context() {
  # Embedded once; reused for every prompt.
  {
    echo "===== BEGIN AGENTS.md ====="
    cat "$AGENTS"
    echo "===== END AGENTS.md ====="
    echo "===== BEGIN DISPATCH FAÇADES (dispatch/) ====="
    cat "$DISPATCH_DIR"/*.md
    echo "===== END DISPATCH FAÇADES ====="
  }
}

build_prompt() {
  # $1 = question. Context is on stdin already via CTX_FILE.
  cat "$CTX_FILE"
  cat <<EOF

===== TASK =====
You are validating comprehension of the operating model above. Answer the
question using ONLY the text above. Do NOT use any tools or read any files.
Think silently, then output your answer as the LAST line, in EXACTLY this
format with no extra words:

VERDICT: YES
or
VERDICT: NO

QUESTION: $1
EOF
}

# An agent's answer file shows it is UNAVAILABLE (not wrong) when it carries a
# credit/auth/quota error rather than a verdict — e.g. amp on the free tier:
# "402 ... require paid credits ... non-interactive". Such an agent is logged
# and EXCLUDED from the pass/fail gate, never scored 0 (which would wrongly
# sink the whole suite). Empty output after a clean timeout counts as a miss,
# not unavailability — that's a real non-answer.
is_unavailable() {
  LC_ALL=C tr -cd '[:print:]\n' < "$1" \
    | grep -qiE '402|paid credits|require.*credits|daily free usage limit|purchase additional credits|quota|rate.?limit|unauthorized|not (logged in|authenticated)|invalid api key|please (log ?in|sign ?in)'
}

extract_verdict() {
  # Last VERDICT: line wins; normalise to YES/NO/?. Strip ANSI/control bytes
  # first — amp & opencode emit colour codes and spinner glyphs that otherwise
  # corrupt the match (and, when interpolated, broke `set -u` on a split byte).
  local v
  v=$(LC_ALL=C tr -cd '[:print:]\n' < "$1" \
        | grep -oiE 'VERDICT:[[:space:]]*(YES|NO)' | tail -1 \
        | grep -oiE '(YES|NO)$' | tr '[:lower:]' '[:upper:]')
  [[ -n "$v" ]] && printf '%s' "$v" || printf '?'
}

# ---- fixture loading (python for robust JSON) -----------------------------
fixtures_field() { # $1=field -> tab-joined id\tfield per line
  python3 -c '
import json,sys
for l in open(sys.argv[1]):
    l=l.strip()
    if not l: continue
    d=json.loads(l)
    print(d["id"]+"\t"+str(d[sys.argv[2]]))
' "$FIXTURES" "$1"
}

validate_fixtures() {
  python3 -c '
import json,sys,re
ids=set(); n=0; bad=0
for i,l in enumerate(open(sys.argv[1]),1):
    l=l.strip()
    if not l: continue
    try: d=json.loads(l)
    except Exception as e: print("BAD JSON line",i,e); bad+=1; continue
    for k in ("id","mode","expect","q","why"):
        if k not in d: print("line",i,"missing",k); bad+=1
    if d.get("expect") not in ("YES","NO"): print("line",i,"bad expect"); bad+=1
    if d.get("id") in ids: print("dup id",d.get("id")); bad+=1
    # Prompt-answerability: the prompt embeds AGENTS.md + gate bodies ONLY, not
    # audits/agents-md.md. A QUESTION that cites the invariance doc / a Scenario
    # number asks for an answer not in the prompt — the agent can only guess, so
    # it grades as "?" and silently drags the score. Enforce that every question
    # is answerable from the embedded ruleset. (The "why" field is provenance for
    # humans and is never sent to the agent, so it may cite Scenario N freely.)
    q = d.get("q","")
    if "AGENTS_INVARIANCE" in q or re.search(r"\bScenario\s+\d", q):
        print("line",i,"question cites AGENTS_INVARIANCE/Scenario (not in prompt):",d.get("id")); bad+=1
    ids.add(d.get("id")); n+=1
print("fixtures:",n)
sys.exit(1 if bad else 0)
' "$FIXTURES"
}

list_available() {
  local a; for a in "${AGENTS_ALL[@]}"; do have "$a" && echo "$a"; done
}

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
declare -A EXPECT QTEXT
while IFS=$'\t' read -r id v; do EXPECT["$id"]="$v"; done < <(fixtures_field expect)
while IFS=$'\t' read -r id v; do QTEXT["$id"]="$v";  done < <(fixtures_field q)

[[ "$MODE" == "smoke" ]] && IDS=("${IDS[0]}")

# Resumability — a long live run can be killed (session restart, Ctrl-C). Each
# agent's verdict is journalled the moment it completes, keyed to HEAD + the
# fixtures hash, so a re-run skips finished agents instead of re-spending tokens.
# A drifted ruleset/fixtures changes RUNKEY → stale journal is ignored. --fresh
# forces a clean run. Journal is gitignored and machine-local.
HEAD_SHA="$(cd "$ROOT" && git rev-parse --short HEAD 2>/dev/null || echo nogit)"
FIX_HASH="$( (md5 -q "$FIXTURES" 2>/dev/null || md5sum "$FIXTURES" 2>/dev/null | cut -d' ' -f1) )"
RUNKEY="${HEAD_SHA}-${FIX_HASH}-t${THRESHOLD}"
RUN_JDIR="$JOURNAL_DIR/$RUNKEY"
[[ "$MODE" == "full" ]] || RUN_JDIR=""          # journal only for full graded runs
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
    build_prompt "${QTEXT[$id]}" > "$pf"
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
[[ -n "$UNAVAIL" ]] && echo && echo "${Y}Unavailable (excluded from gate):${X}$UNAVAIL"

echo; echo "${BO}Summary:${X} $REPORT"

if [[ "$MODE" == "smoke" ]]; then
  echo "${Y}smoke mode${X}: plumbing validated."
  [[ $OVERALL_OK -eq 1 ]] && exit 0 || exit 1
fi

if [[ "$MODE" == "full" && -z "$ONLY_AGENT" && $OVERALL_OK -eq 1 ]]; then
  if [[ $GRADED -eq 0 ]]; then
    echo "${R}🔴 no agent could be graded; all were unavailable${X}"
    exit 1
  fi
  echo "${G}✅ live comprehension passed${X}: graded=$GRADED $REPORT"
  [[ -n "$RUN_JDIR" ]] && rm -rf "$RUN_JDIR"   # run complete — clear its journal
  exit 0
fi

[[ $OVERALL_OK -eq 1 ]] && exit 0 || { echo "${R}🔴 LLM-eval below threshold — see misses${X}"; exit 1; }
