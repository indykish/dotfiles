.PHONY: audit test-audit llmevals llmevals-check signoff

# Run the deterministic audit (script layer of the invariance suite).
audit:
	@bash scripts/audit-agents-md.sh

# Negative-test the audit itself — prove every check still FAILS on a bad
# tree (conformance + determinism). Run whenever audit-agents-md.sh changes.
test-audit:
	@bash scripts/test-audit-agents-md.sh

# Cross-agent LLM eval signoff (AGENTS_INVARIANCE.md Scenario 23): each
# installed agent (claude/codex/amp/opencode) answers the frozen golden-set;
# verdicts graded by exact match. Live LLM calls — costs tokens on every
# agent. Resumable (journalled); writes .agents-llmevals-signoff on
# all-gradable-agents-pass.
llmevals:
	@bash scripts/llmevals/run-llmevals.sh

# Dry validation — fixtures well-formed + agent availability. No live calls.
llmevals-check:
	@bash scripts/llmevals/run-llmevals.sh --check

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
