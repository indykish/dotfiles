# Agent I/O layer for evals/llms/run.sh — prompt construction, headless
# invocation, and answer parsing. Sourced, never executed: run.sh sets ROOT,
# AGENTS, DISPATCH_DIR, CTX_FILE and CALL_TIMEOUT before sourcing this file.
# Split out of run.sh per dispatch/write_any.md §File & Function Length Gate.

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
  # The full embed — used for fixtures with no "ctx" allowlist.
  {
    echo "===== BEGIN AGENTS.md ====="
    cat "$AGENTS"
    echo "===== END AGENTS.md ====="
    echo "===== BEGIN DISPATCH FAÇADES (dispatch/) ====="
    cat "$DISPATCH_DIR"/*.md
    echo "===== END DISPATCH FAÇADES ====="
  }
}

# Fixture-scoped context: __FULL__ = the whole embed above; __NONE__ =
# AGENTS.md alone; otherwise a comma-joined façade allowlist. Scoping cuts a
# ~213KB prompt to the files a fixture actually interrogates.
build_ctx_for() {
  local spec="$1" file
  if [[ "$spec" == "__FULL__" ]]; then cat "$CTX_FILE"; return; fi
  echo "===== BEGIN AGENTS.md ====="
  cat "$AGENTS"
  echo "===== END AGENTS.md ====="
  if [[ "$spec" != "__NONE__" ]]; then
    echo "===== BEGIN DISPATCH FAÇADES (dispatch/) ====="
    local -a ctx_files=()
    IFS=',' read -ra ctx_files <<< "$spec"
    for file in "${ctx_files[@]}"; do cat "$ROOT/$file"; done
    echo "===== END DISPATCH FAÇADES ====="
  fi
}

build_prompt() {
  # $1 = question · $2 = ctx spec (__FULL__ | __NONE__ | comma-joined paths).
  build_ctx_for "${2:-__FULL__}"
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
