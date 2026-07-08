#!/usr/bin/env bash
# dispatch/write_zig.sh — the Zig dispatch, DETERMINISTIC façade.
#
# Pairs with dispatch/write_zig.md (the LATENT façade — prose the agent reads).
# This .sh runs the mechanically-checkable subset of the Zig discipline and
# emits ONE verdict block. The latent trigger ("about to write a *.zig file")
# dispatches here; everything below is deterministic and re-runnable — same
# input, same verdict, no calendar/branch dependence.
#
#   dispatch/write_zig.sh <file.zig> [...]   # explicit targets (EXECUTE)
#   dispatch/write_zig.sh --staged           # staged *.zig (HARNESS VERIFY, pre-commit)
#
# Layering:  AGENTS.md → write_zig.md (latent) → write_zig.sh (this) → audits/*.sh
# Signals:   🟢 pass · 🔴 fail (blocks) · 🔵 DECIDE (judgment; blocks the TURN, not the script)
# Exit:      0 = mechanical gates pass · 1 = ≥1 failed · 2 = usage error.

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

dispatch_init "ZIG" '*.zig'
dispatch_resolve_files "$@"
dispatch_header

# ── deterministic gates ────────────────────────────────────────────
dispatch_length_gate 350                                       # FLL — write_zig.md §Length
# UFS — universal rule enforced once by write_any (see write_any.sh); not re-run here
dispatch_run_helper "DEINIT" "deinit-pairs.sh" "--staged" # write_zig.md §Multi-Step Init

zig_sql_definition_hit() {
  grep -nE '^[[:space:]]*(pub[[:space:]]+)?const[[:space:]]+(SELECT|INSERT|UPDATE|DELETE|UPSERT|LIST|COUNT|EXISTS|[A-Z0-9_]+_(SQL|QUERY)|(SELECT|INSERT|UPDATE|DELETE|UPSERT|LIST|COUNT|EXISTS)_[A-Z0-9_]+)[[:space:]]*=' "$1" | head -1 || true
}

zig_sql_body_hit() {
  grep -nE '^[[:space:]]*\\\\(WITH|SELECT|INSERT|UPDATE|DELETE|CREATE|ALTER|DROP)[[:space:]]' "$1" | head -1 || true
}

zig_added_sql_hit() {
  git -C "$TARGET_ROOT" diff --cached -U0 -- "$1" \
    | awk '/^\+[^+]/ { sub(/^\+/, ""); print }' \
    | grep -nE '^[[:space:]]*(pub[[:space:]]+)?const[[:space:]]+(SELECT|INSERT|UPDATE|DELETE|UPSERT|LIST|COUNT|EXISTS|[A-Z0-9_]+_(SQL|QUERY)|(SELECT|INSERT|UPDATE|DELETE|UPSERT|LIST|COUNT|EXISTS)_[A-Z0-9_]+)[[:space:]]*=|^[[:space:]]*\\\\(WITH|SELECT|INSERT|UPDATE|DELETE|CREATE|ALTER|DROP)[[:space:]]' \
    | head -1 || true
}

zig_sql_module_gate() {
  local code="SQLMOD" g f path base status is_new line
  g="$(dispatch_gloss "$code")"
  for f in "${DISPATCH_FILES[@]}"; do
    path="$TARGET_ROOT/$f"; [ -f "$path" ] || path="$f"; [ -f "$path" ] || continue
    base="$(basename "$f")"
    case "$base" in
      sql.zig|*_test.zig) continue ;;
    esac

    is_new=0
    status="$(git -C "$TARGET_ROOT" diff --cached --name-status -- "$f" | awk 'NR==1 {print $1}')"
    if [[ "$status" == A* ]]; then
      is_new=1
    elif ! git -C "$TARGET_ROOT" ls-files --error-unmatch "$f" >/dev/null 2>&1; then
      is_new=1
    fi
    [ "$is_new" -eq 1 ] || continue

    if [ "$is_new" -eq 1 ]; then
      line="$(zig_sql_definition_hit "$path")"
      if [ -z "$line" ]; then
        line="$(zig_sql_body_hit "$path")"
      fi
    else
      line="$(zig_added_sql_hit "$f")"
    fi
    if [ -n "$line" ]; then
      printf '  %-8s 🔴 %s — %s adds inline SQL (%s); move statements to domain sql.zig\n' "$code" "$g" "$f" "$line"
      DISPATCH_RC=1
    else
      printf '  %-8s 🟢 %s — %s has no new inline SQL statement definitions\n' "$code" "$g" "$f"
    fi
  done
}

zig_sql_module_gate

# ── delegations (checker lives in the product repo, not dotfiles) ───
dispatch_delegate "PUB"      "make lint (zlint unused-decls)"
dispatch_delegate "DRAIN"    "make check-pg-drain (lint-zig.py)"
dispatch_delegate "XCOMPILE" "zig build -Dtarget=x86_64-linux && aarch64-linux"

# ── judgment gates (no script can decide; agent states verdict in chat) ──
dispatch_judgment "TGU"  "result type with distinct failure modes? union(enum) with payload, not optional-field struct"
dispatch_judgment "ARCH" "naming a stream/queue/schema? grep docs/architecture/ first"
dispatch_judgment "FSD"  "new/reshaped *.zig file? file-as-struct vs operations-over-value — decide at PLAN, one-sentence why-not"
dispatch_judgment "DIDEM" "type with a cleanup contract? a test proving deinit is idempotent (or single-shot ownership asserted)"

dispatch_verdict
