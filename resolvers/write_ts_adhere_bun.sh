#!/usr/bin/env bash
# resolvers/write_ts_adhere_bun.sh — the TypeScript / Bun resolver, DETERMINISTIC façade.
#
# Pairs with resolvers/write_ts_adhere_bun.md (the LATENT façade — prose the agent reads).
# This .sh runs the mechanically-checkable subset of the TS/Bun discipline and
# emits ONE verdict block. The latent trigger ("about to write a *.ts/*.tsx/*.js/*.jsx
# file") dispatches here; everything below is deterministic and re-runnable — same
# input, same verdict, no calendar/branch dependence.
#
#   resolvers/write_ts_adhere_bun.sh <file.ts> [...]   # explicit targets (EXECUTE)
#   resolvers/write_ts_adhere_bun.sh --staged          # staged TS/JS (HARNESS VERIFY, pre-commit)
#
# Layering:  AGENTS.md → write_ts_adhere_bun.md (latent) → write_ts_adhere_bun.sh (this) → scripts/*.sh
# Signals:   🟢 pass · 🔴 fail (blocks) · 🔵 DECIDE (judgment; blocks the TURN, not the script) · ⚪ delegated
# Exit:      0 = mechanical gates pass · 1 = ≥1 failed · 2 = usage error.

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

resolver_init "TS" '*.ts' '*.tsx' '*.js' '*.jsx'
resolver_resolve_files "$@"
resolver_header

# ── deterministic gates ────────────────────────────────────────────
resolver_length_gate 350                                       # FLL — write_ts_adhere_bun.md §13 (file ≤ 350)
# UFS — universal rule enforced once by write_any (see write_any.sh); not re-run here

# ── delegations (checker lives in the product repo, not dotfiles) ───
resolver_delegate "TSC" "make lint (oxlint + tsc — const/import/ordering/naming/anti-patterns)"
resolver_delegate "UIS" "make lint (audit-msid-ui.sh — design-system primitive over raw HTML)"
resolver_delegate "DTK" "make lint (audit-design-tokens.sh — token utility over arbitrary value)"

# ── judgment gates (no script can decide; agent states verdict in chat) ──
resolver_judgment "FSD" "new *.ts/*.tsx under src|app|lib? class vs factory vs functions-module vs type-only — decide at PLAN, one-sentence why-not"
resolver_judgment "TGU" "result with distinct failure modes? discriminated union ({ok:true…}|{ok:false…}), not optional-field struct"
resolver_judgment "TSJ" "TS/Bun convention choices (Bun-native over Node-compat, file ordering, error style: throw XOR Result per module)? justify any Node-compat fallback against a concrete dependency constraint"

resolver_verdict
