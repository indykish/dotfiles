#!/usr/bin/env bash
# resolvers/lib.sh — shared framework for all language resolvers.
#
# A resolver (Garry Tan's sense) is a DISPATCHER: given a touched file, it
# resolves which deterministic gates apply and runs them. It never does the
# work itself — the leaf helpers in scripts/ do. This library gives every
# resolver one identical verdict-block format so they cannot drift.
#
# Three entry points, one source of truth (each resolver sources this):
#   EXECUTE        resolvers/<lang>.sh <file>      per-edit, latent early-warning
#   HARNESS VERIFY resolvers/<lang>.sh --staged    end-of-turn aggregate (the anchor)
#   COMMIT         pre-commit → resolvers/<lang>.sh --staged   mechanical backstop
#
# Signal semantics (printed in every row — see RESOLVER_ARCHITECTURE.md §3.1):
#   🟢 GREEN    deterministic check passed                → proceed         (exit 0)
#   🔴 RED      deterministic check failed / helper absent → STOP, fix, rerun (exit 1)
#   🔵 DECIDE   judgment-only; no script can decide        → agent reads §, makes
#               the call, states the verdict in chat; blocks the TURN, not the
#               script (exit 0). 🟡 is reserved for "violations addressed" in
#               HARNESS_VERIFY_OUTPUT.md and is never emitted here.
#   ⚪ N/A       delegated check — runs only in the product repo, not dotfiles
#
# Source this, then call:
#   resolver_init "<LANG>" <ext-glob...>      # e.g. resolver_init "ZIG" '*.zig'
#   resolver_resolve_files "$@"               # populates RESOLVER_FILES[]
#   resolver_length_gate <cap>                # inline length check
#   resolver_run_helper <CODE> <script.sh>    # delegate to scripts/<script.sh>
#   resolver_delegate <CODE> "<command>"      # print a DELEGATED row (in-repo only)
#   resolver_judgment <CODE> "<question>"     # print a 🔵 DECIDE (judgment) row
#   resolver_verdict                          # final ✅/❌ line; exits with status
#
# CODE is a rule code (UFS, FLL, TGU…). Every CODE prints with its gloss from
# RESOLVER_GLOSS so output self-explains — no naked codes (audit-enforced).

set -euo pipefail

# RESOLVER_HOME — where the resolver scripts physically live. Follows a
# sync-agents symlink back to dotfiles, so it always locates lib.sh + the leaf
# helpers correctly. This is NOT the repo being checked.
RESOLVER_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESOLVER_SCRIPTS="$RESOLVER_HOME/scripts"
# TARGET_ROOT — the repo being checked (the one we were invoked from). Derived
# from the CWD's git toplevel, NOT BASH_SOURCE: a symlinked resolver inside a
# product repo must scope --staged discovery + length checks to THAT repo, not
# dotfiles (RESOLVER_ARCHITECTURE.md §10). Falls back to RESOLVER_HOME outside a
# git work tree.
TARGET_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || printf '%s' "$RESOLVER_HOME")"
RESOLVER_LANG=""
RESOLVER_EXTS=()
RESOLVER_FILES=()
RESOLVER_RC=0

# Rule-code gloss map — canonical short expansions (full text in RULES.md legend).
# Keep in sync with RULES.md; audit-resolver-coverage.sh fails on a code with no
# gloss entry. snake-of-record: CODE → "Short Gloss".
declare -A RESOLVER_GLOSS=(
  [NDC]="No Dead Code"
  [NLR]="No Legacy Retained (touch-it-fix-it)"
  [NLG]="No Legacy compat shims (pre-v2.0.0)"
  [UFS]="Unified Form for Symbols (literals → named consts)"
  [TGU]="Tagged-Union over optional-field structs"
  [PRI]="Prompt-injection Resistance from user Input"
  [ORP]="ORPhan sweep (cross-layer on rename/delete)"
  [FLL]="File & Function Length Limits"
  [TST-NAM]="TeST NAMing (milestone-free)"
  [PUB]="Pub Surface & Struct-Shape"
  [DRAIN]="pg.Conn drain-before-deinit"
  [DEINIT]="init/deinit lifecycle pairing"
  [ARCH]="Architecture consult before naming"
  [XCOMPILE]="Cross-compile both linux targets"
  [FSD]="File Shape Decision (file-as-struct vs operations-over-value)"
  [DIDEM]="Deinit IDEMpotency (cleanup double-call safe / single-shot asserted)"
)

# Look up a gloss; empty string if the code is unknown (audit will catch it).
resolver_gloss() { printf '%s' "${RESOLVER_GLOSS[$1]:-}"; }

resolver_init() {
  RESOLVER_LANG="$1"; shift
  RESOLVER_EXTS=("$@")
}

# Resolve targets: explicit file args, or --staged self-discovery via git.
resolver_resolve_files() {
  RESOLVER_FILES=()
  if [ "${1:-}" = "--staged" ]; then
    local pathspecs=() e
    for e in "${RESOLVER_EXTS[@]}"; do pathspecs+=("$e"); done
    while IFS= read -r f; do [ -n "$f" ] && RESOLVER_FILES+=("$f"); done \
      < <(git -C "$TARGET_ROOT" diff --cached --name-only --diff-filter=ACMRT -- "${pathspecs[@]}" \
          | grep -vE '(^|/)(vendor|third_party|node_modules|\.zig-cache|dist|build|\.next)/' || true)
  elif [ "$#" -ge 1 ]; then
    local f matched
    for f in "$@"; do
      matched=0
      for e in "${RESOLVER_EXTS[@]}"; do
        case "$f" in ${e}) matched=1 ;; esac
      done
      if [ "$matched" -eq 1 ]; then RESOLVER_FILES+=("$f")
      else printf 'resolvers: %s does not match %s scope: %s\n' "$RESOLVER_LANG" "${RESOLVER_EXTS[*]}" "$f" >&2; exit 2
      fi
    done
  else
    printf 'usage: resolvers/<lang>.sh <file> [...] | --staged\n' >&2
    exit 2
  fi
}

resolver_header() {
  if [ "${#RESOLVER_FILES[@]}" -eq 0 ]; then
    printf '%s RESOLVER: no files in scope — nothing to dispatch.\n' "$RESOLVER_LANG"
    exit 0
  fi
  printf '%s RESOLVER — %s file(s) in scope\n' "$RESOLVER_LANG" "${#RESOLVER_FILES[@]}"
}

# Inline length gate — intrinsic to the file, deterministic, no git history.
# Code FLL; gloss printed so the human reading a commit knows the rule.
resolver_length_gate() {
  local cap="$1" f n g; g="$(resolver_gloss FLL)"
  for f in "${RESOLVER_FILES[@]}"; do
    local path="$TARGET_ROOT/$f"; [ -f "$path" ] || path="$f"; [ -f "$path" ] || continue
    n="$(wc -l < "$path")"; n="${n//[[:space:]]/}"
    if [ "$n" -gt "$cap" ]; then
      printf '  FLL      🔴 %s — %s: %s lines (cap %s) — split before commit\n' "$g" "$f" "$n" "$cap"
      RESOLVER_RC=1
    else
      printf '  FLL      🟢 %s — %s: %s/%s\n' "$g" "$f" "$n" "$cap"
    fi
  done
}

# Delegate to a deterministic leaf helper in scripts/. Normalizes the verdict.
# CODE prints with its gloss (no naked codes — audit-enforced).
#
# Leaf helpers have NON-UNIFORM arg contracts (e.g. audit-deinit-pairs takes
# --staged; audit-ufs takes --all/no-arg after M70). The caller MUST pass the
# mode the helper actually accepts as the 3rd arg — never assume --staged.
#   resolver_run_helper UFS    audit-ufs.sh          --all
#   resolver_run_helper DEINIT audit-deinit-pairs.sh --staged
resolver_run_helper() {
  local code="$1" script="$2" mode="${3:-}" g; g="$(resolver_gloss "$code")"
  # An absent DETERMINISTIC helper is 🔴, never a silent ⚪/0: a deleted or
  # un-synced leaf must NOT pass as a green no-op (RESOLVER_ARCHITECTURE.md §10).
  # ⚪ is reserved for resolver_delegate (checks that legitimately don't run here).
  if [ ! -f "$RESOLVER_SCRIPTS/$script" ]; then
    printf '  %-8s 🔴 %s — DETERMINISTIC helper absent (scripts/%s) — cannot verify\n' "$code" "$g" "$script"
    RESOLVER_RC=1
    return 1
  fi
  local log="/tmp/resolver-${RESOLVER_LANG}-${code}.log"
  if bash "$RESOLVER_SCRIPTS/$script" $mode >"$log" 2>&1; then
    printf '  %-8s 🟢 %s — pass (scripts/%s %s)\n' "$code" "$g" "$script" "$mode"
  else
    printf '  %-8s 🔴 %s — fail (scripts/%s %s) — see %s\n' "$code" "$g" "$script" "$mode" "$log"
    RESOLVER_RC=1
  fi
}

# A gate that can only run inside the project repo (not dotfiles). Print, don't run.
resolver_delegate() {
  local code="$1" cmd="$2" g; g="$(resolver_gloss "$code")"
  printf '  %-8s ⚪ %s — DELEGATED → %s\n' "$code" "$g" "$cmd"
}

# A judgment gate that NO script can pass/fail (architecture, legacy-design,
# greptile, tagged-unions). 🔵 DECIDE = open question, NOT a failure: exit stays 0
# but the TURN is incomplete until the agent states a verdict in chat (see §3.1).
# 🔵 (not 🟡) so it never collides with HARNESS_VERIFY's "violations addressed" 🟡.
# Faking determinism on a taste decision is the anti-goal.
resolver_judgment() {
  local code="$1" question="$2" g; g="$(resolver_gloss "$code")"
  printf '  %-8s 🔵 DECIDE — %s: %s\n' "$code" "$g" "$question"
}

resolver_verdict() {
  if [ "$RESOLVER_RC" -eq 0 ]; then
    printf '%s RESOLVER: ✅ all dispatched gates pass (delegations pending in-repo)\n' "$RESOLVER_LANG"
  else
    printf '%s RESOLVER: ❌ one or more gates failed — fix before commit\n' "$RESOLVER_LANG"
  fi
  exit "$RESOLVER_RC"
}
