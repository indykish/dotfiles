.PHONY: audit test-audit comprehension comprehension-check signoff

# Run the deterministic audit (script layer of the invariance suite).
audit:
	@bash scripts/audit-agents-md.sh

# Negative-test the audit itself — prove every check still FAILS on a bad
# tree (conformance + determinism). Run whenever audit-agents-md.sh changes.
test-audit:
	@bash scripts/test-audit-agents-md.sh

# Cross-agent comprehension signoff (AGENTS_INVARIANCE.md Scenario 23): each
# installed agent (claude/codex/amp/opencode) answers the frozen golden-set;
# verdicts graded by exact match. Live LLM calls — costs tokens on every
# agent. Writes .agents-comprehension-signoff on all-agents-pass.
comprehension:
	@bash scripts/comprehension/run-comprehension.sh

# Dry validation — fixtures well-formed + agent availability. No live calls.
comprehension-check:
	@bash scripts/comprehension/run-comprehension.sh --check

# Write the AGENTS_INVARIANCE sign-off file against current HEAD.
# Only run this AFTER answering every AGENTS_INVARIANCE.md question with YES.
# The pre-push hook reads .agents-invariance-signoff to allow contract pushes.
signoff:
	@printf '%s  %s  PASS\n' \
	  "$$(git rev-parse --short HEAD)" \
	  "$$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
	  > .agents-invariance-signoff
	@echo "wrote .agents-invariance-signoff:"
	@cat .agents-invariance-signoff
