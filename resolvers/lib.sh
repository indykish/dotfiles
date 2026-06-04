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
# Source this, then call:
#   resolver_init "<LANG>" <ext-glob...>      # e.g. resolver_init "ZIG" '*.zig'
#   resolver_resolve_files "$@"               # populates RESOLVER_FILES[]
#   resolver_length_gate <cap>                # inline length check
#   resolver_run_helper <LABEL> <script.sh>   # delegate to scripts/<script.sh>
#   resolver_delegate <LABEL> "<command>"     # print a DELEGATED row (in-repo only)
#   resolver_verdict                          # final ✅/❌ line; exits with status

set -euo pipefail

RESOLVER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESOLVER_SCRIPTS="$RESOLVER_ROOT/scripts"
RESOLVER_LANG=""
RESOLVER_EXTS=()
RESOLVER_FILES=()
RESOLVER_RC=0

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
      < <(git -C "$RESOLVER_ROOT" diff --cached --name-only --diff-filter=ACMRT -- "${pathspecs[@]}" \
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
resolver_length_gate() {
  local cap="$1" f n
  for f in "${RESOLVER_FILES[@]}"; do
    local path="$RESOLVER_ROOT/$f"; [ -f "$path" ] || path="$f"; [ -f "$path" ] || continue
    n="$(wc -l < "$path")"; n="${n//[[:space:]]/}"
    if [ "$n" -gt "$cap" ]; then
      printf '  LENGTH  🔴 %s: %s lines (cap %s) — split before commit\n' "$f" "$n" "$cap"
      RESOLVER_RC=1
    else
      printf '  LENGTH  🟢 %s: %s/%s\n' "$f" "$n" "$cap"
    fi
  done
}

# Delegate to a deterministic leaf helper in scripts/. Normalizes the verdict.
resolver_run_helper() {
  local label="$1" script="$2"
  if [ ! -f "$RESOLVER_SCRIPTS/$script" ]; then
    printf '  %-8s ⚪ helper not present (scripts/%s) — skipped\n' "$label" "$script"
    return 0
  fi
  local log="/tmp/resolver-${RESOLVER_LANG}-${label}.log"
  if bash "$RESOLVER_SCRIPTS/$script" --staged >"$log" 2>&1; then
    printf '  %-8s 🟢 pass (scripts/%s)\n' "$label" "$script"
  else
    printf '  %-8s 🔴 fail (scripts/%s) — see %s\n' "$label" "$script" "$log"
    RESOLVER_RC=1
  fi
}

# A gate that can only run inside the project repo (not dotfiles). Print, don't run.
resolver_delegate() {
  printf '  %-8s ⚪ DELEGATED → %s\n' "$1" "$2"
}

# A judgment/design-consult gate that NO script can pass/fail (architecture,
# legacy-design, greptile triage). Surfaced as a visible un-passable reminder
# so it is never silently skipped — the agent must answer it in chat. Does not
# affect exit status; faking determinism on a taste decision is the anti-goal.
resolver_judgment() {
  printf '  %-8s 🟡 JUDGMENT — %s\n' "$1" "$2"
}

resolver_verdict() {
  if [ "$RESOLVER_RC" -eq 0 ]; then
    printf '%s RESOLVER: ✅ all dispatched gates pass (delegations pending in-repo)\n' "$RESOLVER_LANG"
  else
    printf '%s RESOLVER: ❌ one or more gates failed — fix before commit\n' "$RESOLVER_LANG"
  fi
  exit "$RESOLVER_RC"
}
