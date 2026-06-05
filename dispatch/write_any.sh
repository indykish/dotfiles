#!/usr/bin/env bash
# dispatch/write_any.sh — the cross-cutting authoring dispatch, DETERMINISTIC façade.
#
# Pairs with dispatch/write_any.md (the LATENT façade — prose the agent reads).
# Fires for ANY source file, IN ADDITION to the language façade (write_zig /
# write_ts_adhere_bun / write_sql). Runs the mechanically-checkable cross-cutting
# subset and emits ONE verdict block.
#
#   dispatch/write_any.sh <file> [...]   # explicit targets (EXECUTE)
#   dispatch/write_any.sh --staged       # staged source (HARNESS VERIFY, pre-commit)
#
# Layering:  AGENTS.md → write_any.md (latent) → write_any.sh (this) → audits/*.sh
# Signals:   🟢 pass · 🔴 fail (blocks) · 🔵 DECIDE (judgment; blocks the TURN, not the script) · ⚪ delegated
# Exit:      0 = mechanical gates pass · 1 = ≥1 failed · 2 = usage error.
#
# Leaf modes are verified against each script's own arg-parser (lib.sh warns the
# contracts are NON-UNIFORM): ufs.sh takes --all only (--staged retired M70);
# logging.sh / error-codes.sh / msid-ui.sh all accept --staged.
# The fn≤50/method≤70 sub-cap (write_any.md, file-length card) is a TODO-CHECK:
# dispatch_length_gate enforces only the file cap; no fn/method leaf is wired yet.

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

dispatch_init "ANY" '*.zig' '*.ts' '*.tsx' '*.js' '*.jsx' '*.py' '*.rs' '*.go' '*.sh' '*.sql'
dispatch_resolve_files "$@"
dispatch_header

# ── deterministic gates ────────────────────────────────────────────
dispatch_length_gate 350                                       # FLL — file cap (fn/method 50/70 = TODO-CHECK)
dispatch_run_helper "UFS"  "ufs.sh"          "--all"
dispatch_run_helper "LOG"  "logging.sh"      "--staged"
dispatch_run_helper "MSID" "msid-ui.sh"      "--staged"

# ── delegations (run only in the product repo — need state absent from dotfiles) ──
# ERR's leaf hard-exits if src/zombied/errors/error_registry.zig is absent (it
# cross-references emitted codes against the registry), unlike UFS/LOG/MSID which
# pass gracefully on empty input. So it can't run in dotfiles — delegate it; the
# product repo's `make harness-verify` runs error-codes.sh against the real
# registry. The .md keeps [DETERMINISTIC → ERR]: deterministic, just not run here.
dispatch_delegate "ERR" "make harness-verify (error-codes.sh — needs src/zombied/errors/error_registry.zig)"

# ── judgment gates (no script can decide; agent states verdict in chat) ──
dispatch_judgment "GRP" "per-iteration (diff langs change) + end-of-turn: audit the diff against docs/greptile-learnings/RULES.md — one row per applicable code (UFS/ORP/TST-NAM/PRI/EMS/…); \"it's just a label\" is not an exception"
dispatch_judgment "NLR" "touching a file with legacy framing / dead code? clean it in the same diff (touch-it-fix-it), or state the surviving legacy + why — never retain silently"
dispatch_judgment "NLG" "new legacy_* / V2 twin / compat shim / tracking-list while VERSION < 2.0.0? rename to the what-is-wrong form; no new legacy framing pre-2.0"
dispatch_judgment "LDC" "patching / keeping / testing a legacy-design path? consult Indy — A (remove) / B (patch) / C (keep) — before proceeding; no unilateral call"

dispatch_verdict
