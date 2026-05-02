.PHONY: audit signoff

# Run the deterministic audit (script layer of the invariance suite).
audit:
	@bash scripts/audit-agents-md.sh

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
