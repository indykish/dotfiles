.PHONY: audit test-audit llmevals \
        dispatch-coverage dispatch-evals dispatch-parity

# Run the deterministic audit chain (all green):
#   1. Registry and profile validation.
#   2. Oracle rules unit tests and byte-stable rendering.
#   3. AGENTS.md invariance and dispatch checks.
audit:
	@bin/orly validate
	@cd orly && bun run typecheck && bun test src
	@bin/orly verify --all
	@bash audits/ufs.sh --all
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

# Cross-agent Large Language Model (LLM) evaluation (Scenario 23): each
# installed agent (claude/codex/amp/opencode) answers the frozen golden-set;
# verdicts graded by exact match. Live LLM calls — costs tokens on every
# agent. The run is resumable through a machine-local journal.
#
# One entry point. The live run validates fixtures + reports availability as a
# mandatory preamble (run.sh:188) before any spend. For the zero-token
# dry path (CI / runner unavailable, Scenario 23.8) pass CHECK=1:
#   make llmevals          — live graded run (costs tokens)
#   make llmevals CHECK=1  — validate fixtures + availability only, no live calls
llmevals:
	@bash evals/llms/run.sh $(if $(CHECK),--check)
