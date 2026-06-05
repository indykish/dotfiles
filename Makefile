.PHONY: audit test-audit llmevals signoff \
        dispatch-coverage dispatch-evals dispatch-parity

# Run the deterministic audit chain (all green):
#   1. agents-md.sh          — AGENTS.md invariance + dispatch parity (script layer).
#   2. dispatch-coverage.sh  — dispatch façade-pair coherence (6.3 + 6.4).
#   3. evals/dispatch/run.sh — prose-pinned deterministic façade evals.
audit:
	@bash audits/agents-md.sh
	@bash evals/dispatch/coverage.sh
	@bash evals/dispatch/run.sh

# Dispatch façade-pair coherence in isolation (tags ↔ checks ↔ fixtures ↔
# probes ↔ leaf-helpers ↔ canonical gloss legend).
dispatch-coverage:
	@bash evals/dispatch/coverage.sh

# Deterministic dispatch evals in isolation — pass+fail fixture per code.
dispatch-evals:
	@bash evals/dispatch/run.sh

# Negative-test the audit itself — prove every check still FAILS on a bad
# tree (conformance + determinism). Run whenever agents-md.sh changes.
test-audit:
	@bash evals/test-agents-md.sh

# Dispatch-parity proof — runs audits/parity-dispatch.sh against a model-B
# sandbox (docs/gates/ empty, AGENTS.md dispatch table, 10 entries) and asserts
# it goes green AND bites. agents-md.sh now sources the same check (check 9b);
# this isolates + proves it against synthetic regressions.
dispatch-parity:
	@bash evals/test-dispatch-parity.sh

# Cross-agent LLM eval signoff (audits/agents-md.md Scenario 23): each
# installed agent (claude/codex/amp/opencode) answers the frozen golden-set;
# verdicts graded by exact match. Live LLM calls — costs tokens on every
# agent. Resumable (journalled); writes .agents-llmevals-signoff on
# all-gradable-agents-pass.
#
# One entry point. The live run validates fixtures + reports availability as a
# mandatory preamble (run.sh:188) before any spend. For the zero-token
# dry path (CI / runner unavailable, Scenario 23.8) pass CHECK=1:
#   make llmevals          — live graded run (costs tokens)
#   make llmevals CHECK=1  — validate fixtures + availability only, no live calls
llmevals:
	@bash evals/llms/run.sh $(if $(CHECK),--check)

# Write the AGENTS_INVARIANCE sign-off file against current HEAD.
# Only run this AFTER answering every audits/agents-md.md question with YES.
# The pre-push hook reads .agents-invariance-signoff to allow contract pushes.
signoff:
	@printf '%s  %s  PASS\n' \
	  "$$(git rev-parse --short HEAD)" \
	  "$$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
	  > .agents-invariance-signoff
	@echo "wrote .agents-invariance-signoff:"
	@cat .agents-invariance-signoff
