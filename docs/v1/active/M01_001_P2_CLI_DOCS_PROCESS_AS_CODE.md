<!--
SPEC AUTHORING RULES (load-bearing — the one comment that survives):
- Body order = the executing agent's read order. Fill via the kishore-spec-new
  skill (authoring order lives there); after filling, DELETE every "tpl:"
  guidance comment — the SPEC TEMPLATE GATE blocks tpl residue, unfilled
  {slots}, and missing required sections (audits/spec-template.sh --staged).
- No time/effort/hour/day estimates anywhere. No effort columns, complexity
  ratings, percentage-complete, implementation dates, assigned owners.
- Priority (P0/P1/P2/P3) is the only sizing signal; Dependencies are the only
  sequencing signal. A section that contradicts these rules loses — delete it.
-->

# M01_001: Process-as-code — `orly gate` PR-boundary engine + thin rule distribution

**Prototype:** v1.0.0
**Milestone:** M01
**Workstream:** 001
**Date:** Jul 27, 2026
**Status:** IN_PROGRESS
**Priority:** P2 — governance tooling; no customer surface, but every future milestone's flow runs through it
**Categories:** CLI, DOCS
**Batch:** B1 — no parallel siblings
**Branch:** `feat/m01-process-as-code`
**Test Baseline:** `unit=25` (25 pass / 0 fail across 7 files, `cd orly && bun test src`)
**Depends on:** none
**Provenance:** LLM-drafted (Claude Opus 5 authoring; Fable 5 architecture review; external ChatGPT verdict P+F+C; Jul 27, 2026)
**Canonical architecture:** `docs/ORLY_ARCHITECTURE.md` — rewritten by §5 of this spec; the rewrite IS the shape definition

---

## Overview

**Goal (testable):** `orly gate pr` exits 0 only when every PR-boundary criterion passes or carries a recorded override trailer — in all three federated repos, spec or no spec — and a rule edit reaches every agent session through one dotfiles commit with zero consumer sync commits.
**Problem:** 21 of the last 36 file-touching dotfiles commits are hash-rebaseline ceremony; 3 of 4 federated repos are red on `orly doctor`; downstream-first rule fixes get flagged as integrity violations; lifecycle stages are enforced only by four stochastic agent runtimes interpreting 32 KB of prose.
**Solution summary:** Encode the lifecycle's boundaries as derived gates in the orly Command-Line Interface (CLI) — ordered gate groups (work → verify → pr) whose criteria are profile commands plus built-in checks, evaluated fresh from git and the working tree on every run; git history is the only state record. Simultaneously delete rule *distribution*: the root `AGENTS.md` render (symlinked into every agent home) becomes the sole rules carrier, consumer repos thin to one hand-authored `AGENTS.md`, and executable gates resolve from the dotfiles checkout. The Secure Hash Algorithm (SHA-256) ledger, manifests, digests, and push-time live Large Language Model (LLM) evals are removed.

## PR Intent & comprehension handshake

- **PR title (eventual):** `feat(orly): lifecycle engine + thin rule distribution`
- **Intent (one sentence):** Movement through the engineering lifecycle refuses to advance on red, and rule changes cost one commit total — replacing prose-hoped determinism and per-repo file ceremony.
- **Handshake** — the implementing agent fills this at PLAN, before EXECUTE: restate the Intent in its own words and list `ASSUMPTIONS I'M MAKING: …`. A mismatch between the restatement and the Intent above → STOP and reconcile before any edit.

## Implementing agent — read these first

1. `orly/src/repository.ts` — house patterns: `Bun.spawnSync` git interrogation, `OrlyError`, clean-tree guards; `linkAgentHomes` survives as the distribution carrier.
2. `orly/src/render.ts` + `orly/src/references.ts` — render pipeline being slimmed; pack-marker filtering and reference-closure stay for the root render.
3. `~/Projects/oss/cli` — supabase-style CLI pillars: command→handler→errors split, handler purity, structured errors (SOUL.md reference-repo rule).
4. `.githooks/pre-push` + `audits/agents-md.sh` — enforcement surfaces being scoped/retargeted; agents-md.sh already has zero ledger references and keeps auditing root `AGENTS.md`.
5. `~/Projects/agentsfleet/make/harness.mk` — the consumer gate-invocation surface §6 repoints at dotfiles.

## Files Changed (blast radius)

Blast-radius grep executed at authoring: `grep -rln 'ruleset.lock|ruleset_digest|profileDigest|registryDigest|tampered-lock'` → 15 files, all listed.

| File | Action | Why |
|------|--------|-----|
| `docs/REST_API_DESIGN_GUIDELINES.md` | EDIT | §1 port-up: banned-vocab fixes + two owner-approved agentsfleet exception blocks (pack-markered) |
| `docs/VERIFY_TIERS.md` | EDIT | §1 port-up: agentsfleet's evolved copy is the truth; replace wholesale |
| `orly/src/gates.ts` | CREATE | §2–§3 gate groups, ordered runner, override-trailer scan |
| `orly/src/criteria.ts` | CREATE | §2 exit-criterion definitions + evaluation (LENGTH GATE split from lifecycle.ts) |
| `orly/src/surfaces.ts` | CREATE | §2 branch-diff classification: user-surface, docs, code (Dimensions 2.6–2.7) |
| `orly/src/{gates,criteria,surfaces}.test.ts` | CREATE | engine unit/integration/e2e tests |
| `orly/src/cli.ts` | EDIT | verbs `gate`/`override`; drop `sync <repo>`/`--all`/`adopt` |
| `orly/src/repository.ts` | EDIT | delete distribution/adoption/replacement guards; keep agent-home linking |
| `orly/src/render.ts` | EDIT | render global → root `AGENTS.md`; delete lock/manifest writing and `verifyLock` |
| `orly/src/model.ts` | EDIT | delete `profileDigest`/`registryDigest`/`contentDigest`/`implementationSources` |
| `orly/src/verify.ts` | EDIT | idempotence + root-render currency; evidence drops `registry_digest` |
| `orly/src/{cli,model,render,references,repository,verify}.test.ts` | EDIT | follow the surviving surfaces |
| `orly/registry.json` | EDIT | render.stable fail fixture swapped; packs keep `managed_files` as validated inventory (sources must exist) — nothing copies them |
| `orly/profiles/*.json` | EDIT | keep `packs` + `commands{}` (the Model C command surface) + optional `surfaces{user,docs}` prefix lists |
| `orly/fixtures/tampered-lock.json` → `orly/fixtures/unclosed-pack-block.md` | DELETE + CREATE | genuine render-failure fail fixture replaces the ledger one |
| `orly/schemas/ruleset-lock.schema.json` DELETE; `orly/schemas/evidence.schema.json` | EDIT | ledger schema gone; evidence drops `registry_digest` |
| `orly/generated/**` | DELETE | root `AGENTS.md` becomes the one render target; homes relink to it |
| `AGENTS.md` | EDIT | regenerated: digest-free header; lifecycle prose from §5 |
| `orly/core/operating-model.md` | EDIT | lifecycle names `orly next` as driver; anchor invariant; LAND/SHIP prose-manual note |
| `.oracle/ruleset.lock`, `.oracle/profile.json`, `.oracle/managed-files.json` | DELETE | ledger artifacts (dotfiles self-copies) |
| `.agents-comprehension-signoff`, `.agents-invariance-signoff` | DELETE | zero references anywhere — orphans |
| `bin/update-ai-tools`, `bin/update-skills` | EDIT | `orly doctor --all` → `orly doctor` (home links + root currency); skills step renders the root `AGENTS.md` |
| `.githooks/pre-push` | EDIT | audit+evidence scoped to governance paths; live LLM smoke removed (manual/scheduled) |
| `audits/agents-md.md` | EDIT | reword 4 ledger rows; add Scenario 27 (engine semantics) |
| `audits/data.sh` | EDIT | `NAMED_SCENARIOS` +1 for Scenario 27 |
| `audits/spec-template.sh` | EDIT | `--file <path>` mode so the engine's spec.gate calls the same enforcer (one source of truth) |
| `dispatch/edit_rules.md` | EDIT | required-action list loses lock/digest/push-smoke language |
| `docs/ORLY_ARCHITECTURE.md` | EDIT | rewrite: P+F+C topology, anchor invariant, provenance-in-commit-message |
| `README.md` | EDIT | propagation/doctor sections match the thin model |
| `~/Projects/agentsfleet/{dispatch/**, audits/<orly-managed>, docs/<orly-managed>, .oracle/**, AGENTS.project.md}` | DELETE | §6 thin migration (one agentsfleet commit) |
| `~/Projects/agentsfleet/{AGENTS.md, make/harness.mk, audits/gitleaks-config.sh}` | EDIT | thin hand-authored AGENTS.md; gates resolve from dotfiles; lock carve-out removed |
| `~/Projects/cache-kit.rs/{<orly-managed copies>, .oracle/**, AGENTS.project.md}` | DELETE + thin `AGENTS.md` EDIT | §6 migration |
| `~/Projects/docs/{<orly-managed copies>, .oracle/**, AGENTS.project.md}` | DELETE + thin `AGENTS.md` EDIT | §6 migration |

## Applicable Rules

- **`docs/greptile-learnings/RULES.md`** — NDC (deletions complete, no stranded helpers), NLR (touch-it-fix-it on every edited file), NLG (no compat shims for removed verbs), ORP (orphan sweep: signoffs, `generated/`, fixtures, schemas), UFS (named constants in new TS).
- `dispatch/write_ts_adhere_bun.md` — all `orly/src` edits: const/import discipline, Bun primitives, TS FILE SHAPE DECISION for `lifecycle.ts` at PLAN.
- `dispatch/write_shell.md` — `.githooks/pre-push`, `audits/data.sh`, `audits/spec-template.sh` edits: quoted expansions, array arguments.
- `dispatch/edit_rules.md` — the whole diff is governance: `make audit` green per commit, questionnaire answered, no agent override.
- `dispatch/write_spec.md` + `docs/TEMPLATE.md` — this spec and the TEMPLATE edit.
- `docs/DOCUMENTATION_RULES.md` — README edits.

## Applicable Gates

| Gate | Fires? | Satisfaction strategy |
|------|--------|-----------------------|
| ZIG GATE | no — no `*.zig` touched | — |
| PUB / Struct-Shape | yes (TS) — new `lifecycle.ts` pub surface | FILE SHAPE DECISION recorded at PLAN; verbs thin in `cli.ts`, logic in `lifecycle.ts` |
| File & Function Length (≤350/≤50/≤70) | yes | `lifecycle.ts` designed ≤350; `render.ts`/`repository.ts` shrink; split before cap |
| UFS (repeated/semantic literals) | yes | state names, section headings, verb strings as named constants |
| UI Substitution / DESIGN TOKEN | no — no UI surface | — |
| LOGGING / LIFECYCLE / ERROR REGISTRY / SCHEMA | no — orly console output is the product interface; no product logging surface | — |
| SPEC TEMPLATE GATE | yes — this file + TEMPLATE edit | `audits/spec-template.sh --staged` clean before each commit |
| edit_rules (no override) | yes — entire diff | audit + questionnaire + evidence per `dispatch/edit_rules.md` |

## Prior-Art / Reference Implementations

- **Reference:** `orly/src/*` — existing `OrlyError`/const/spawnSync idiom; new code reads like the surrounding code.
- **Reference:** supabase-style `~/Projects/oss/cli` — 7-pillars alignment: command→handler→errors split, handler purity (no `process.exit` in handlers), structured error text with the failing criterion + its command. Divergence: no auto-JSON output in v1 — the sole consumers are agents reading text; recorded as Out of Scope.
- **Reference:** `git status --porcelain` UX — `orly status`/`next` print machine-stable, line-oriented verdicts; one line per criterion.
- **External verdict:** ChatGPT consult (Discovery) — P (state machine) + F (thin distribution) + C (repo command surface) composition; states coarse; escape hatches exactly three.

## Sections (implementation slices)

### §1 — Port downstream truth up

agentsfleet's copies evolved ahead of the source; deleting consumer copies (§6) without porting first loses owner-approved content. **Implementation default:** the two REST exception blocks stay wrapped in `oracle-packs:start product.agentsfleet` markers — under thin distribution the markers become scope labels, no longer rendered away.

- **Dimension 1.1** — DONE — REST guide source carries the downstream taste fixes (guarantee-wording, stage-wording in the state-field list) and both exception blocks → Test `grep_rest_guide_ported`
- **Dimension 1.2** — DONE — `VERIFY_TIERS.md` source replaced wholesale with agentsfleet's evolved copy (coverage lanes, integration roots, rewritten memleak lanes) → Test `grep_verify_tiers_ported`

### §2 — PR-boundary gates (Model P, simplified: verdicts, no stored state)

Redesigned mid-milestone after Indy's simplicity challenge (Discovery). The first build stored state in a spec-resident Transitions table — a second ledger inside git, the same mistake the SHA ledger made one layer up, and it could not run in cache-kit (`docs/v0.9.2/`) or the docs repo (no spec tree). Gates replace it: every verdict is derived fresh from git + the working tree; git history is the only record.

- **Dimension 2.1** — DONE — gate groups, ordered: `work` (branch, tree, profile) → `verify` (spec dimensions when a spec exists · conform · fast suites) → `pr` (tree, pushed, spec gate + dimensions, docs.updated, slow suites); `orly gate` runs them in order and stops at the first red group; `orly gate <name>` runs one; `--list` prints the plan; all read-only → Test `test_gate_groups_and_first_red`
- **Dimension 2.2** — DONE — spec checks are conditional, never demanded: no active spec → spec criteria skip with a printed reason (ad-hoc bug fixes gate clean); more than one active spec → red (one stream per worktree); discovery accepts every real layout (`docs/v2/`, `docs/v0.9.2/`) → Test `test_spec_optional_and_layouts`
- **Dimension 2.3** — DONE — `docs.updated` (pr gate): profile-declared user-surface prefixes touched (test files and `.md` excluded) with no same-branch docs change (spec tree `docs/v*/` never counts as docs) → red, printing the exact override command → Test `test_docs_updated_criterion`
- **Dimension 2.4** — DONE — tiered suites: `conform` + fast `verify.*` in the verify gate; the fixed slow set (`verify.integration`, `verify.memory`) in the pr gate, auto-passing with a printed skip when the branch diff carries no code files → Test `test_slow_suites_skip_on_prose_only`

### §3 — Override (owner authority, recorded in git)

One escape hatch, not three: parking is closing the worktree, resetting is git. `orly override <criterion> --reason <REASON>` writes an **empty commit** carrying an `Orly-Override:` trailer — immutable once pushed, visible in the PR, dead with the branch. Gates scan merge-base..HEAD for trailers; a red criterion with a matching trailer reports `overridden`, never plain green.

- **Dimension 3.1** — DONE — override trailer: empty reason refused; trailer parsed strictly (`Orly-Override: <criterion> (<reason>)`); scoped to the branch, so it cannot leak past merge → Test `test_override_trailer_recorded_not_green`

### §4 — Thin distribution (Model F)

One render target: dotfiles root `AGENTS.md`. Agent homes symlink to it. Consumers carry no orly-managed files. **Implementation default:** provenance moves to sync-commit messages; the generated header names only the profile — render becomes a pure function of (sources, profile), so byte-diff currency checks never see phantom drift.

- **Dimension 4.1** — DONE — `orly sync` renders root `AGENTS.md` + relinks all four agent homes; `orly/generated/` deleted → Test `test_render_targets_root`
- **Dimension 4.2** — DONE — ledger machinery deleted: lock/manifest writing, `verifyLock`, digest functions, `sync <repo>`/`adopt` verbs, replacement/adoption guards, `filterManagedText` → Test `grep_zero_ledger_symbols`
- **Dimension 4.3** — DONE — render.stable fail fixture = `unclosed-pack-block.md` (a genuine render failure); ledger schema deleted; evidence schema drops `registry_digest`; packs keep validated `managed_files` inventory → Test `test_validate_slim_registry`
- **Dimension 4.4** — DONE — `orly verify --all` = per-profile double-render idempotence + root-render currency; `orly doctor` = home links + root currency; `bin/update-ai-tools` repointed → Test `test_verify_currency`

### §5 — Prose + enforcement retarget

- **Dimension 5.1** — operating model, one editing pass: lifecycle names `orly next` as the sole driver + anchor invariant; LAND prose-manual recipe (merge → checkout default → pull → prune worktree+branch → stash-compare-drop → `make down` where the repo defines it); PR budget (one PR per milestone, or draft + one, never more); review route unified (every runtime uses gstack `/review`; Codex native review dropped); skill chain gains `/write-integration-test` before PR; babysit row names CI check runs + greptile inline + PR-level threads; regenerated `AGENTS.md` ≤ 32,768 bytes → Test `audit_size_and_headers`
- **Dimension 5.5** — writing voice: no-ai-slop editing rules land in `docs/DOCUMENTATION_RULES.md` (docs Orly writes) and `SOUL.md` (decisions Orly explains — simple, user-case-first, the four-step risk rubric); the review-route change sweeps `audits/agents-md.sh` check 5, `audits/data.sh`, `audits/agents-md.md`, `evals/`, and `docs/ORLY_ARCHITECTURE.md` in the same commit → Test `audit_named_scenarios`
- **Dimension 5.2** — `.githooks/pre-push`: `make audit` + evidence only when the pushed range touches governance paths; live `llmevals` removed from hooks (manual `make llmevals` stays) → Test `grep_prepush_scoped`
- **Dimension 5.3** — questionnaire: 4 ledger rows reworded; Scenario 27 (engine semantics: what advances, what halts, how overrides record) + `NAMED_SCENARIOS` parity → Test `audit_named_scenarios`
- **Dimension 5.4** — `ORLY_ARCHITECTURE.md` + `README.md` rewritten for the gates model → Test `audit_spec_gate_transitions`

### §6 — Consumer migration (one commit per repo)

- **Dimension 6.1** — agentsfleet: orly-managed copies + `.oracle/` + `AGENTS.project.md` deleted; thin hand-authored `AGENTS.md` (project facts + command table + operating-model pointer); `make/harness.mk` resolves gates from `ORLY_ROOT ?= $(HOME)/Projects/dotfiles`; gitleaks lock carve-out removed; `make harness-verify` green → Test `rubric_agentsfleet_thin`
- **Dimension 6.2** — cache-kit.rs: copies + `.oracle/` deleted (5 gate scripts had no invoker); thin `AGENTS.md` → Test `rubric_cachekit_thin`
- **Dimension 6.3** — docs repo: same shape → Test `rubric_docs_thin`

## Interfaces

```
orly next                     advance one transition, or exit 1 with per-criterion red lines
orly status                   current state + last transitions + next criteria (read-only)
orly check <state>            exit 0 iff <state>'s entry criteria hold (read-only, CI-safe)
orly override <criterion> --reason "…"    append OVERRIDE row (owner authority)
orly park --reason "…"   |   orly reset --to <state> --reason "…"
orly sync --global | doctor | render | validate | verify --all     (surviving verbs)

orly gate [--list|--accept-dirty]   run work → verify → pr in order; stop at
                                    the first red GROUP; report every criterion
orly gate <work|verify|pr>          run one group
orly override <criterion> --reason <REASON>
                                    empty commit with trailer:
                                    "Orly-Override: <criterion> (<reason>)"
Exit codes: 0 all green · 1 red · 2 usage error. Nothing is ever written by
`gate`; `override` writes exactly one empty commit.

Gate groups — every criterion is MECHANICAL (the machine runs a check and
reads an exit code or a file). Unprovable claims stay prose, never criteria.
  work    git.branch (not the default branch) · git.tree (clean, or
          --accept-dirty; the active spec never counts) · repo.profile
  verify  spec.dimensions (when a spec exists) · cmd.conform ·
          fast cmd.verify.* (unit, lint, version, …)
  pr      git.tree · git.pushed · spec.gate + spec.dimensions (when a spec
          exists) · docs.updated (user surface touched ⇒ docs touched;
          overridable) · slow suites (verify.integration, verify.memory —
          auto-pass with printed skip when the branch has no code files)

Branch diff = merge-base(default branch, HEAD)..HEAD. Classification is pure:
user surface = profile surfaces.user prefix AND source extension AND not a test
file; docs = profile surfaces.docs prefix AND never docs/v*/ (the spec tree);
code = source extension or a test path. Overrides = Orly-Override trailers in
merge-base..HEAD commit bodies. Cross-repo user docs (the sibling docs
repository) are not machine-provable from this diff — they stay a CHORE(close)
obligation graded by the rubric.
```

## Failure Modes

| Mode | Cause | Handling (system response + what the caller observes) |
|------|-------|--------------------------------------------------------|
| Red criterion | any gate command fails | print criterion + command + one output line; stop at that group; exit 1; nothing written |
| No active spec | ad-hoc branch, no spec tree | spec criteria print "skipped — no active spec" and pass; quality gates still run |
| Two active specs | parallel streams in one tree | red naming both paths (one stream per worktree) |
| Profile missing / unregistered repo | repo absent from `repositories.json` | cmd criteria absent; `repo.profile` red naming the registry file; never a crash |
| Empty override reason | `--reason ""` or omitted | refuse, exit 2; no commit created |
| Malformed hand-written trailer | trailer text does not parse | ignored (not an override); gate stays red naming the criterion |
| Broken home link | symlink target moved/deleted | `orly doctor` red naming the link and target |
| Consumer gate path absent | dotfiles not at `ORLY_ROOT` on a machine | consumer `make` fails loudly printing the expected path (documented in harness.mk) |
| Override of a load-bearing criterion | owner records the trailer | allowed; empty commit visible in the PR; reported `overridden`, never green |

## Invariants

1. Anchor — `orly gate pr` exits 0 only when every pr-gate criterion is green or carries a matching `Orly-Override` trailer in merge-base..HEAD — enforced by `gates.ts` having a single evaluation path and no write path.
2. Gates derive, never store — no gate command writes any file; the only state is git — enforced by construction (read-only evaluation) + negative test.
3. Render purity — `render(sources, profile)` twice → byte-identical — enforced by the retained idempotence check in `orly verify --all`.
4. Zero ledger artifacts — no lock/digest/manifest files or symbols anywhere — enforced by deletion + rubric R4 grep.
5. `AGENTS.md` ≤ 32,768 bytes — enforced by `audits/agents-md.sh` check 16 (unchanged).
6. Overrides carry a non-empty reason inside a strict trailer — argument validation + strict parse + negative test.

## Metrics & Observability

| Metric / event | Owner | Fires when | Properties allowed | Privacy guard | Test proof |
|----------------|-------|------------|--------------------|---------------|------------|
| not applicable — no product/operator signal changes; `orly status`/`next` output is the operator surface | — | — | — | — | — |

## Test Specification (tiered)

| Dimension | Tier | Test | Asserts (concrete inputs → expected output) |
|-----------|------|------|---------------------------------------------|
| 1.1 | gate (grep) | `grep_rest_guide_ported` | banned-vocab grep → 0 hits; both exception blocks present with markers |
| 1.2 | gate (grep) | `grep_verify_tiers_ported` | coverage-lane + integration-root headings present in source |
| 2.1 | unit | `test_gate_groups_and_first_red` | ordered run stops at the first red group; later groups unevaluated |
| 2.2 | unit | `test_spec_optional_and_layouts` | no spec → spec criteria skip; two active specs → red; v0.9.2 layout discovered |
| 2.3 | integration | `test_docs_updated_criterion` | user-surface change with no docs change → red naming the override command |
| 2.1 | e2e (subprocess) | `test_e2e_gate_walk` | fixture repo: `orly gate` red → fix → `orly gate` green → `orly gate pr` green, via the real CLI |
| 2.4 | unit | `test_slow_suites_skip_on_prose_only` | prose-only branch skips integration/memory with printed reason; code branch runs them |
| 3.1 | unit | `test_override_trailer_recorded_not_green` | trailer satisfies its criterion, reported `overridden`; malformed trailer ignored |
| 3.1 | unit | `test_override_requires_reason` | empty reason → exit 2, no commit created |
| 4.1 | unit | `test_render_targets_root` | render writes root `AGENTS.md`; no `.oracle/` outputs; homes relink |
| 4.2 | gate (grep) | `grep_zero_ledger_symbols` | word-boundary greps for deleted symbols → 0 matches (Dead Code Sweep) |
| 4.3 | unit | `test_validate_slim_registry` | validate passes slim registry; fail fixture `unclosed-pack-block.md` makes render throw |
| 4.4 | unit | `test_verify_currency` | stale root `AGENTS.md` → verify red naming the file; regenerate → green |
| 5.1–5.4 | gate | `make audit` | full chain green: size cap, scenarios parity, spec gate |
| 6.1–6.3 | rubric (manual command) | `rubric_*_thin` | R7 commands per repo; agentsfleet `make harness-verify` green from dotfiles-resolved gates |
| regression | unit | existing render/reference tests | pack-marker filtering + reference closure behave unchanged for the root render |
| regression | integration | `orly doctor` home links | pre-existing green `doctor --global` behavior preserved on the new target |

## Acceptance Rubric (single scoring surface)

| # | Criterion (observable outcome) | Verify (copy-paste) | Expected | Priority | Graded (VERIFY) |
|---|--------------------------------|---------------------|----------|----------|-----------------|
| R1 | Engine + surviving orly tests pass (§2–§4) | `cd orly && bun test src` | exit 0 | P0 | |
| R2 | Diff stays inside Files Changed | `git diff --name-only origin/master...HEAD` | 0 paths missing from the Files Changed table | P0 | |
| R3 | Governance audit green (§5) | `make audit` | `ALL CHECKS PASSED` | P0 | |
| R4 | Zero ledger artifacts (§4) | `grep -rEn 'ruleset\.lock\|ruleset_digest\|profileDigest\|registryDigest' orly/src audits dispatch docs README.md` | 0 matches | P0 | |
| R5 | Port-up landed (§1) | `grep -nE '\b(contract\|phase)\b' docs/REST_API_DESIGN_GUIDELINES.md docs/VERIFY_TIERS.md` | 0 matches | P0 | |
| R6 | Homes link to root render (§4) | `readlink ~/.claude/CLAUDE.md && bin/orly doctor` | path ends `/dotfiles/AGENTS.md`; exit 0 | P0 | |
| R7 | agentsfleet thin + gates resolve (§6) | `test ! -d ~/Projects/agentsfleet/dispatch && test ! -d ~/Projects/agentsfleet/.oracle && (cd ~/Projects/agentsfleet && make harness-verify)` | exit 0 | P0 | |
| R8 | Hooks scoped, smoke off push path (§5) | `grep -c 'GOVERNANCE' .githooks/pre-push; grep -c 'llmevals' .githooks/pre-push` | first ≥1; second = 0 | P0 | |
| R9 | Spec corpus clean (§5) | `bash audits/spec-template.sh --all` | exit 0 | P0 | |
| S7 | No secrets | `gitleaks detect` | exit 0 | P0 | |
| S8 | No oversize source file | `git diff --name-only origin/master...HEAD \| grep -v '\.md$' \| xargs wc -l 2>/dev/null \| awk '$1>350 && $2!="total"'` | no output | P0 | |
| S9 | Orphan sweep | Dead Code Sweep greps below | 0 matches | P0 | |

**Grading protocol (VERIFY):** run the Verify command verbatim; grade ONLY from its output. Graded = ✅/❌ + the one decisive output line. **Ship gate:** every row graded, every P0 ✅ → eligible for CHORE(close); any ❌ or empty cell → return to EXECUTE; a P1 ❌ ships only with an Indy-acked deferral quote in Discovery.

## Dead Code Sweep

**1. Orphaned files — deleted from disk and git.**

| File to delete | Verify |
|----------------|--------|
| `.oracle/ruleset.lock` + `.oracle/profile.json` + `.oracle/managed-files.json` | `test ! -f .oracle/ruleset.lock -a ! -f .oracle/profile.json -a ! -f .oracle/managed-files.json` |
| `orly/generated/` | `test ! -d orly/generated` |
| `orly/fixtures/tampered-lock.json` | `test ! -f orly/fixtures/tampered-lock.json` |
| `orly/schemas/ruleset-lock.schema.json` | `test ! -f orly/schemas/ruleset-lock.schema.json` |
| `.agents-comprehension-signoff` + `.agents-invariance-signoff` | `test ! -f .agents-comprehension-signoff -a ! -f .agents-invariance-signoff` |
| consumer orly-managed trees (per repo) | R7-shape `test ! -d` commands per repo |

**2. Orphaned references — zero remaining imports/uses.**

| Deleted symbol/import | Grep | Expected |
|-----------------------|------|----------|
| `verifyLock` | `grep -rnw 'verifyLock' orly/src \| head` | 0 matches |
| `profileDigest` / `registryDigest` / `implementationSources` | `grep -rnwE 'profileDigest\|registryDigest\|implementationSources' orly/src \| head` | 0 matches |
| `syncRepository` / `adoptRepository` | `grep -rnwE 'syncRepository\|adoptRepository' orly/src \| head` | 0 matches |
| `RULESET_LOCK` / `MANIFEST_PATH` | `grep -rnwE 'RULESET_LOCK\|MANIFEST_PATH' orly/src \| head` | 0 matches |

## Out of Scope

- LAND/SHIP machine states (`pr-ready → landed → deployed → observed`) — v2 spec; prose-manual until then. `PR_READY → DONE` (CHORE(close)) is likewise hand-recorded in v1: `DONE` exists in the state enum for Status derivation, but no transition into it is implemented.
- Non-mechanizable exit criteria — changelog/docs-page currency and Dead Code Sweep were considered for `VERIFIED→PR_READY` and cut: no honest machine signal exists for them here (dotfiles' changelog lives in a sibling repo). They remain prose obligations enforced at CHORE(close) and graded by the Acceptance Rubric. Adding them later means adding a real signal, not a checkbox.
- CI enforcement (`orly check pr-ready` as a protected-branch check) — needs Indy's explicit CI-edit approval; named follow-up.
- Generated per-repo operating brief for cloud visitors — build only on demonstrated need.
- Deleting the llmevals/questionnaire corpus — demoted off the push path here; removal is a later cleanup once the engine proves itself.
- Auto-JSON output mode; multi-writer concurrency beyond tail-validation; engine support for spec-less trivial work.

---

## Product Clarity (authoring record)

1. **Successful user moment** — Indy (or an agent) types `orly next` in a worktree and gets either `→ EXECUTING` or an exact red list naming each failing criterion, its command, and one output line.
2. **Preserved user behaviour** — `make audit`, agent-home symlinks, `kishore-spec-new` authoring, worktree flow, conventional commits, `kishore-babysit-prs` all work unchanged.
3. **Optimal-way check** — direct; the one gap: the engine *checks* motions (worktree creation, spec moves) rather than performing them — acceptable: git owns mutations, the engine owns verdicts.
4. **Rebuild-vs-iterate** — iterate on existing orly; refactor verdict recorded in Decomposition. Determinism strictly increases; nothing trades it away.
5. **What we build** — `lifecycle.ts` + verb wiring; ledger deletion; root-render distribution; prose/enforcement retarget; three thin-consumer migrations.
6. **What we do NOT build** — Out of Scope list above (CI wiring, v2 states, brief, JSON mode).
7. **Fit with existing features** — compounds with spec authoring (gate at PENDING→PLANNED) and babysit (post-push arm); must not destabilize `make audit` — green at every commit.
8. **Surface order** — CLI-first (repo default); only surface.
9. **Dashboard restraint** — N/A — no UI; `status` prints only machine-verifiable facts, no quality claims.
10. **Confused-user next step** — `orly status` names the failing criterion and its exact command; exit-2 paths name the fixing tool (`kishore-spec-new`, profile file, expected path).

## Decomposition & alternatives (patch vs refactor)

- **Chosen shape:** six Sections — port-up first (§1, data preservation before deletion), engine before thinning (§2–§4, so `verify` gains root-currency while distribution still green), prose/enforcement retarget (§5), migrations last (§6, one commit per consumer).
- **Alternatives considered:** de-ledger-only (keep copies, delete hashes) — rejected: leaves the process prose-enforced and N×M sync forever. Full machine through deploy — rejected for v1: merge/deploy involve external systems, permissions, retries; contaminates the first loop (external verdict). Command surface alone without state (Model C only) — rejected: answers "ready now?" but not "what's legal next / was an override used".
- **Patch-vs-refactor verdict:** this is a **refactor** because the failure is structural — the ledger and prose-hoped determinism are the wrong architecture; a patch preserves it. The follow-up refactor (v2 LAND/SHIP states) is named, not silently folded in.

## Discovery (consult log)

- **Consults** — Architecture: Jul 27, 2026 session — Opus 5 review + Fable 5 subagent audit (ledger self-refuting; dual delivery via global symlink; downstream-first fixes) + external ChatGPT verdict (P+F+C; coarse states; escape hatches; anchor invariant on movement). Indy decisions: process-as-code foundation; distribution ceremony dies; stage vocabulary retained.
- **Mid-milestone redesign (Indy simplicity challenge, Jul 27, 2026 evening):** the first engine stored state in a spec-resident Transitions table and could not run in cache-kit (`docs/v0.9.2/`) or the docs repo (no spec tree) — a second ledger inside git, the SHA mistake one layer up. Replaced by derived gates; the two transitions it recorded before removal: PENDING→PLANNED (bootstrap, 04:35 PM), PLANNED→EXECUTING (green via `orly next`, 07:21 PM). Indy process rules added same session: docs-before-PR gate, slow suites only on code change, one PR per milestone (draft + one max), gstack `/review` on every runtime, babysit reads CI + inline + threads, merge-cleanup recipe incl. `make down` container teardown, no-ai-slop voice for decisions and docs, judgment-ask glyphs 📍🧰💎🚨 (visibility-revised).
- **CHORE(open) deviation — no sibling worktree; branch cut in the main checkout.** The agent-home symlinks (`~/.claude/CLAUDE.md` and siblings) must resolve to a path that survives the branch, and §4.1 retargets them at `~/Projects/dotfiles/AGENTS.md`. A sibling worktree would either link agents at a directory removed post-merge or leave them on stale rules. Consequence accepted: a new agent session started mid-EXECUTE reads partially-rebuilt rules. Same-tree matches the operating model's stated default.
- **Metrics review** — no analytics/funnel playbook update required: internal governance tooling, no product signal.
- **Skill-chain outcomes** — (populated at VERIFY/CHORE(close)).
- **Deferrals** — none.
