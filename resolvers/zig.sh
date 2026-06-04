#!/usr/bin/env bash
# resolvers/zig.sh — the Zig resolver (dispatch layer).
#
# Resolver, in Garry Tan's sense: it does NOT do the work. Given a touched
# *.zig file, it RESOLVES which deterministic gates apply, runs the leaf
# helpers in scripts/, and emits ONE verdict block. The latent-space
# trigger ("about to touch a *.zig file") dispatches here; everything
# below this line is deterministic and re-runnable — same input, same
# verdict, no calendar/branch dependence.
#
#   resolvers/zig.sh <file.zig> [<file.zig> ...]   # explicit targets
#   resolvers/zig.sh --staged                       # staged *.zig (pre-commit)
#
# Layering:
#   resolvers/zig.sh   — this dispatcher (the "which gates apply" decision)
#   scripts/*.sh       — deterministic leaf helpers (the actual checks)
#   docs/gates/*.md    — the rule bodies (the "what" + "why")
#
# Gates dispatched:
#   LENGTH  — flat 300-line hard cap for *.zig (stricter than universal 350).
#             Intrinsic to the file; new and old alike. docs/gates/file-length.md
#   UFS     — RULE UFS via scripts/audit-ufs.sh.            docs/gates/ufs.md
#   DEINIT  — init/deinit pairing via scripts/audit-deinit-pairs.sh.
#                                                           docs/gates/lifecycle.md
#
# Project-repo delegations (not runnable from dotfiles — printed as DELEGATED):
#   PUB     — zlint unused-decls (make lint).               docs/gates/pub-surface.md
#   DRAIN   — make check-pg-drain / lint-zig.py.            docs/ZIG_RULES.md
#   XCOMPILE— zig build -Dtarget=x86_64-linux && aarch64-linux.
#
# Exit: 0 = all dispatched gates pass · 1 = ≥1 gate failed · 2 = usage error.

set -euo pipefail

readonly ZIG_LINE_CAP=300
readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SCRIPTS_DIR="$REPO_ROOT/scripts"

# --- argument resolution -----------------------------------------------------
FILES=()
if [ "${1:-}" = "--staged" ]; then
  while IFS= read -r f; do [ -n "$f" ] && FILES+=("$f"); done \
    < <(git -C "$REPO_ROOT" diff --cached --name-only --diff-filter=ACMRT -- '*.zig' \
        | grep -vE '(^|/)(vendor|third_party|\.zig-cache)/' || true)
elif [ "$#" -ge 1 ]; then
  for f in "$@"; do
    case "$f" in
      *.zig) FILES+=("$f") ;;
      *) printf 'resolvers/zig.sh: not a .zig file: %s\n' "$f" >&2; exit 2 ;;
    esac
  done
else
  printf 'usage: resolvers/zig.sh <file.zig> [...] | --staged\n' >&2
  exit 2
fi

if [ "${#FILES[@]}" -eq 0 ]; then
  printf 'ZIG RESOLVER: no *.zig files in scope — nothing to dispatch.\n'
  exit 0
fi

# --- gate: LENGTH (inline, deterministic, intrinsic) -------------------------
length_gate() {
  local rc=0 f n
  for f in "${FILES[@]}"; do
    [ -f "$REPO_ROOT/$f" ] || [ -f "$f" ] || continue
    n="$(wc -l < "${REPO_ROOT}/${f}" 2>/dev/null || wc -l < "$f")"
    n="${n//[[:space:]]/}"
    if [ "$n" -gt "$ZIG_LINE_CAP" ]; then
      printf '  LENGTH  🔴 %s: %s lines (cap %s) — split before commit\n' "$f" "$n" "$ZIG_LINE_CAP"
      rc=1
    else
      printf '  LENGTH  🟢 %s: %s/%s\n' "$f" "$n" "$ZIG_LINE_CAP"
    fi
  done
  return $rc
}

# --- gate: delegate to a leaf helper, normalize the verdict line -------------
run_helper() {
  local label="$1" script="$2"
  if [ ! -x "$SCRIPTS_DIR/$script" ] && [ ! -f "$SCRIPTS_DIR/$script" ]; then
    printf '  %-7s ⚪ helper not present (scripts/%s) — skipped\n' "$label" "$script"
    return 0
  fi
  if bash "$SCRIPTS_DIR/$script" --staged >/tmp/zig-resolver-$label.log 2>&1; then
    printf '  %-7s 🟢 pass (scripts/%s)\n' "$label" "$script"
    return 0
  else
    printf '  %-7s 🔴 fail (scripts/%s) — see /tmp/zig-resolver-%s.log\n' "$label" "$script" "$label"
    return 1
  fi
}

# --- dispatch ----------------------------------------------------------------
printf 'ZIG RESOLVER — %s file(s) in scope\n' "${#FILES[@]}"
overall=0

length_gate || overall=1
run_helper "UFS"    "audit-ufs.sh"          || overall=1
run_helper "DEINIT" "audit-deinit-pairs.sh" || overall=1

# delegations — cannot run from dotfiles; surfaced so the agent runs them in-repo
printf '  PUB     ⚪ DELEGATED → make lint (zlint unused-decls) in project repo\n'
printf '  DRAIN   ⚪ DELEGATED → make check-pg-drain in project repo\n'
printf '  XCOMPILE⚪ DELEGATED → zig build -Dtarget=x86_64-linux && aarch64-linux\n'

if [ "$overall" -eq 0 ]; then
  printf 'ZIG RESOLVER: ✅ all dispatched gates pass (delegations pending in-repo)\n'
else
  printf 'ZIG RESOLVER: ❌ one or more gates failed — fix before commit\n'
fi
exit "$overall"
