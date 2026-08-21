.PHONY: audit test-audit llmevals ledger install-evals \
        dispatch-coverage dispatch-evals dispatch-parity ledger-evals

# Run the deterministic audit chain (all green):
#   1. Registry and profile validation.
#   2. Oracle rules unit tests and byte-stable rendering.
#   3. AGENTS.md invariance and dispatch checks.
audit:
	@cd orly && bun run typecheck && bun test src
	@bin/orly verify
	@bash audits/ufs.sh --all
	@bash audits/agents-md.sh
	@bash evals/dispatch/coverage.sh
	@bash evals/dispatch/run.sh
	@bash evals/ledger/run.sh
	@bash audits/rule-ledger.sh --check
	@bash evals/install/run.sh

# Installability in isolation — the payload boundary and a packed tarball
# proving itself against a scratch HOME with no dotfiles checkout in reach.
install-evals:
	@bash evals/install/run.sh

# What each rule document actually enforces: one row per registered doc,
# clause census by enforcement class. Reports; never gates on counts.
ledger:
	@bash audits/rule-ledger.sh --census

# Ledger behaviour in isolation — fixture-pinned census and scoreboard cases.
ledger-evals:
	@bash evals/ledger/run.sh

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
