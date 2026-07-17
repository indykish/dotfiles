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
# installed agent (claude/codex/amp/opencode) answers frozen fixtures; verdicts
# are graded by exact match. Live calls cost tokens on every agent. The full run
# is resumable through a machine-local journal.
#
# One entry point. The live run validates fixtures + reports availability as a
# mandatory preamble (run.sh:188) before any spend. For the zero-token
# dry path pass CHECK=1. Pre-push uses the fixed smoke path:
#   make llmevals          — full live graded run
#   make llmevals SMOKE=1  — one live fixture per installed agent
#   make llmevals CHECK=1  — validate all fixtures, no live calls
llmevals:
	@bash evals/llms/run.sh $(if $(CHECK),--check,$(if $(SMOKE),--smoke))
