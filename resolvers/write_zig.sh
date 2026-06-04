#!/usr/bin/env bash
# resolvers/write_zig.sh — the Zig resolver, DETERMINISTIC façade.
#
# Pairs with resolvers/write_zig.md (the LATENT façade — prose the agent reads).
# This .sh runs the mechanically-checkable subset of the Zig discipline and
# emits ONE verdict block. The latent trigger ("about to write a *.zig file")
# dispatches here; everything below is deterministic and re-runnable — same
# input, same verdict, no calendar/branch dependence.
#
#   resolvers/write_zig.sh <file.zig> [...]   # explicit targets (EXECUTE)
#   resolvers/write_zig.sh --staged           # staged *.zig (HARNESS VERIFY, pre-commit)
#
# Layering:  AGENTS.md → write_zig.md (latent) → write_zig.sh (this) → scripts/*.sh
# Signals:   🟢 pass · 🔴 fail (blocks) · 🔵 DECIDE (judgment; blocks the TURN, not the script)
# Exit:      0 = mechanical gates pass · 1 = ≥1 failed · 2 = usage error.

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

resolver_init "ZIG" '*.zig'
resolver_resolve_files "$@"
resolver_header

# ── deterministic gates ────────────────────────────────────────────
resolver_length_gate 350                                       # FLL — write_zig.md §Length
# UFS — universal rule enforced once by write_any (see write_any.sh); not re-run here
resolver_run_helper "DEINIT" "audit-deinit-pairs.sh" "--staged" # write_zig.md §Multi-Step Init

# ── delegations (checker lives in the product repo, not dotfiles) ───
resolver_delegate "PUB"      "make lint (zlint unused-decls)"
resolver_delegate "DRAIN"    "make check-pg-drain (lint-zig.py)"
resolver_delegate "XCOMPILE" "zig build -Dtarget=x86_64-linux && aarch64-linux"

# ── judgment gates (no script can decide; agent states verdict in chat) ──
resolver_judgment "TGU"  "result type with distinct failure modes? union(enum) with payload, not optional-field struct"
resolver_judgment "ARCH" "naming a stream/queue/schema? grep docs/architecture/ first"
resolver_judgment "FSD"  "new/reshaped *.zig file? file-as-struct vs operations-over-value — decide at PLAN, one-sentence why-not"
resolver_judgment "DIDEM" "type with a cleanup contract? a test proving deinit is idempotent (or single-shot ownership asserted)"

resolver_verdict
