#!/usr/bin/env bash
# evals/dispatch/run.sh — prose-pinned deterministic-façade evals (DISPATCH_ARCHITECTURE.md 6.1).
#
# Each fixture is a source file crafted to trip EXACTLY ONE deterministic dispatch
# code (or none, for the *_ok pass fixtures). The runner drops it into an isolated
# git sandbox, stages it, runs the owning dispatch `--staged` from inside the
# sandbox (so TARGET_ROOT = sandbox and the leaf checks scan the fixture, not
# dotfiles), and diffs the actual exit against the expected one.
#
# Why a sandbox: the leaf checks (audit-ufs / audit-logging / audit-msid-ui /
# audit-deinit-pairs) scan `git rev-parse --show-toplevel`'s tree (src/*.zig via
# git ls-files / find src) — never a passed file path. A fixture must therefore
# live in a git tree they actually scan.
#
# The boundary pairs (length_350_pass / length_351_fail) PIN the prose bound: edit
# write_*.sh's dispatch_length_gate cap and the 351 fixture flips, turning this
# runner red — the fixture, not a tag, is the drift detector (DISPATCH_ARCHITECTURE
# §3). ERR is intentionally absent: it is deterministic-but-DELEGATED (its leaf
# needs the product-repo error_registry.zig), so it has no in-dotfiles fixture
# (§16 Decision 6 / the delegate is exercised by the product harness instead).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FX="$ROOT/evals/dispatch/fixtures"

# fixture | dispatch | sandbox-dest | expected-exit | code-under-test
SPECS=(
  "length_350_pass.zig|write_zig|src/length_350_pass.zig|0|FLL"
  "length_351_fail.zig|write_zig|src/length_351_fail.zig|1|FLL"
  "ufs_ok.zig|write_any|src/ufs_ok.zig|0|UFS"
  "ufs_dup_string.zig|write_any|src/ufs_dup_string.zig|1|UFS"
  "log_ok.zig|write_any|src/log_ok.zig|0|LOG"
  "log_violation.zig|write_any|src/log_violation.zig|1|LOG"
  "msid_ok.zig|write_any|src/msid_ok.zig|0|MSID"
  "msid_violation.zig|write_any|src/msid_violation.zig|1|MSID"
  "deinit_ok.zig|write_zig|src/deinit_ok.zig|0|DEINIT"
  "deinit_missing.zig|write_zig|src/deinit_missing.zig|1|DEINIT"
  "sqlmod_ok.zig|write_zig|src/sqlmod_ok.zig|0|SQLMOD"
  "sqlmod_violation.zig|write_zig|src/sqlmod_violation.zig|1|SQLMOD"
)

pass=0
fail=0
printf '\ndispatch-evals — prose-pinned deterministic fixtures\n\n'
for spec in "${SPECS[@]}"; do
  IFS='|' read -r fx dispatch dest exp code <<<"$spec"
  sb="$(mktemp -d)"
  git -C "$sb" init -q
  git -C "$sb" config user.email evals@local
  git -C "$sb" config user.name evals
  mkdir -p "$sb/$(dirname "$dest")"
  cp "$FX/$fx" "$sb/$dest"
  git -C "$sb" add -A
  ( cd "$sb" && bash "$ROOT/dispatch/$dispatch.sh" --staged ) >/dev/null 2>&1
  act=$?
  rm -rf "$sb"
  if [ "$act" = "$exp" ]; then
    printf '  PASS  %-5s %-22s %s --staged -> exit %s\n' "$code" "$fx" "$dispatch" "$act"
    pass=$((pass + 1))
  else
    printf '  FAIL  %-5s %-22s %s --staged -> exit %s (expected %s)\n' "$code" "$fx" "$dispatch" "$act" "$exp"
    fail=$((fail + 1))
  fi
done
printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
