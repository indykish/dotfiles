#!/usr/bin/env bash
# evals/install/run.sh — proves the harness installs into a repository that has
# never seen this checkout.
#
# Every case runs against a throwaway directory with a scratch HOME, so a green
# suite means the behaviour survives a machine that carries no dotfiles at all —
# the property the whole milestone exists to buy. Case bodies live in cases.sh;
# this file is the driver and the sandbox machinery.
#
# Usage: bash evals/install/run.sh [name-filter]
set -uo pipefail

# Gate scripts inherit git's scope when a hook invokes them. Left alone, a
# sandbox `git add -A` stages fixture paths into the real index.
unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE GIT_COMMON_DIR GIT_PREFIX \
      GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES

ROOT="${ORLY_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
FILTER="${1:-}"

if [[ -t 1 ]]; then G=$'\033[32m'; R=$'\033[31m'; BO=$'\033[1m'; X=$'\033[0m'
else G=''; R=''; BO=''; X=''; fi
PASS=0; FAIL=0; SANDBOXES=()
cleanup() { local d; for d in "${SANDBOXES[@]+"${SANDBOXES[@]}"}"; do rm -rf "$d"; done; }
trap cleanup EXIT

ok()  { printf '  %sPASS%s  %s\n' "$G" "$X" "$1"; PASS=$((PASS + 1)); }
bad() { printf '  %sFAIL%s  %s — %s\n' "$R" "$X" "$1" "$2" >&2; FAIL=$((FAIL + 1)); }

# A scratch directory that is not inside the checkout and carries its own HOME,
# so nothing under ~/Projects/dotfiles can satisfy a lookup by accident.
mk_sandbox() {
  local sb; sb="$(mktemp -d)"; SANDBOXES+=("$sb")
  mkdir -p "$sb/home"
  printf '%s' "$sb"
}

# The published payload, extracted. Built once and reused: `npm pack` is the
# slowest thing in the suite and its output is identical for every case.
TARBALL_ROOT=""
packed_root() {
  if [[ -n "$TARBALL_ROOT" ]]; then printf '%s' "$TARBALL_ROOT"; return 0; fi
  local sb; sb="$(mk_sandbox)"
  ( cd "$ROOT" && npm pack --pack-destination "$sb" ) >/dev/null 2>&1 || return 1
  ( cd "$sb" && tar xzf ./*.tgz ) >/dev/null 2>&1 || return 1
  TARBALL_ROOT="$sb/package"
  printf '%s' "$TARBALL_ROOT"
}

# The manifest's file list, one path per line, without unpacking anything.
packed_paths() {
  ( cd "$ROOT" && npm pack --dry-run --json 2>/dev/null ) \
    | grep -oE '"path": *"[^"]+"' | sed -E 's/.*: *"//; s/"$//'
}

# An initialised repository with one commit, so gate criteria that read git
# history have something to read.
mk_repo() {
  local sb; sb="$(mk_sandbox)"
  git -C "$sb" init -q -b main
  git -C "$sb" config user.email "evals@example.invalid"
  git -C "$sb" config user.name "install evals"
  printf '# fixture\n' > "$sb/README.md"
  git -C "$sb" add -A >/dev/null 2>&1
  git -C "$sb" commit -qm "fixture baseline" >/dev/null 2>&1
  printf '%s' "$sb"
}

# Run an orly command from the packed payload against a target directory, with
# HOME pointed away from the developer's own configuration.
run_packed() {
  local pkg="$1" cwd="$2"; shift 2
  ( cd "$cwd" && env HOME="$cwd/home" PATH="$PATH" bash "$pkg/bin/orly" "$@" 2>&1 )
}

# shellcheck source=cases.sh
source "$(dirname "${BASH_SOURCE[0]}")/cases.sh"

printf '\n%sinstall evals%s (root: %s)\n\n' "$BO" "$X" "$ROOT"
for case_name in $(declare -F | awk '{print $3}' | grep '^install_' | sort); do
  [[ -n "$FILTER" && "$case_name" != *"$FILTER"* ]] && continue
  "$case_name"
done

printf '\n  %d passed / %d failed\n\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
