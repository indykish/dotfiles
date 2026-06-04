#!/usr/bin/env bash
# resolvers/write_sql.sh — the SQL / schema resolver, DETERMINISTIC façade.
#
# Pairs with resolvers/write_sql.md (the LATENT façade — prose the agent reads).
# This .sh runs the mechanically-checkable subset of the SQL/schema discipline and
# emits ONE verdict block. The latent trigger ("about to write a schema/*.sql file")
# dispatches here; everything below is deterministic and re-runnable.
#
#   resolvers/write_sql.sh <schema/file.sql> [...]   # explicit targets (EXECUTE)
#   resolvers/write_sql.sh --staged                  # staged schema/*.sql (HARNESS VERIFY, pre-commit)
#
# Layering:  AGENTS.md → write_sql.md (latent) → write_sql.sh (this) → scripts/*.sh
# Signals:   🟢 pass · 🔴 fail (blocks) · 🔵 DECIDE (judgment; blocks the TURN, not the script) · ⚪ delegated
# Exit:      0 = mechanical gates pass · 1 = ≥1 failed · 2 = usage error.
#
# Note: STS/NSQ/SGR are mechanizable SQL-hygiene rules with no leaf check wired yet
# (write_sql.md tags them TODO-CHECK). They stay in docs/greptile-learnings/RULES.md
# (retained) and the GREPTILE GATE enforces them by review until a leaf exists.
# SCH's pre-2.0 forbidden-token floor (no ALTER/DROP/SELECT 1; in schema/*.sql) is
# itself a build-the-check (TODO-CHECK) candidate; the teardown-vs-ALTER disposition
# call above it stays JUDGMENT (which file to rm, which @embedFile, which migration index).

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

resolver_init "SQL" 'schema/*.sql'
resolver_resolve_files "$@"
resolver_header

# ── deterministic gates ────────────────────────────────────────────
resolver_length_gate 350                                       # FLL — file ≤ 350

# ── judgment gates (no script can decide; agent states verdict in chat) ──
resolver_judgment "SCH" "removing/altering a table? cat VERSION — pre-2.0.0 = full teardown (rm schema/NNN.sql + @embedFile + migration-array entry + index tests), never ALTER/DROP/SELECT 1; ≥2.0.0 = numbered ALTER/DROP migration. print the SCHEMA GUARD block"
resolver_judgment "ITF" "integration test touching a production table? seed via src/db/test_fixtures_<scope>.zig against the real schema — never CREATE TEMP TABLE mocking the production shape"

resolver_verdict
