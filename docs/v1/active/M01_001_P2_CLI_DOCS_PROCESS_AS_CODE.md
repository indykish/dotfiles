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

# M01_001: Process-as-code — `orly next` lifecycle engine + thin rule distribution

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

**Goal (testable):** `orly next` advances a spec PENDING→PR_READY only when the current transition's declared exit criteria all pass (or carry a recorded override), and a rule edit reaches every agent session through one dotfiles commit with zero consumer sync commits.
**Problem:** 21 of the last 36 file-touching dotfiles commits are hash-rebaseline ceremony; 3 of 4 federated repos are red on `orly doctor`; downstream-first rule fixes get flagged as integrity violations; lifecycle stages are enforced only by four stochastic agent runtimes interpreting 32 KB of prose.
**Solution summary:** Encode the lifecycle as a state machine in the orly Command-Line Interface (CLI) — states are the existing stage vocabulary, exit criteria are profile commands plus built-in checks, and an append-only `## Transitions` log in the spec is the state record. Simultaneously delete rule *distribution*: the root `AGENTS.md` render (symlinked into every agent home) becomes the sole rules carrier, consumer repos thin to one hand-authored `AGENTS.md`, and executable gates resolve from the dotfiles checkout. The Secure Hash Algorithm (SHA-256) ledger, manifests, digests, and push-time live Large Language Model (LLM) evals are removed.

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
| `orly/src/lifecycle.ts` | CREATE | §2–§3 state graph, transition log, exit-criteria evaluation, escape hatches |
| `orly/src/lifecycle.test.ts` | CREATE | engine unit/integration/e2e tests |
| `orly/src/cli.ts` | EDIT | verbs `next`/`status`/`check`/`override`/`park`/`reset`; drop `sync <repo>`/`--all`/`adopt` |
| `orly/src/repository.ts` | EDIT | delete distribution/adoption/replacement guards; keep agent-home linking |
| `orly/src/render.ts` | EDIT | render global → root `AGENTS.md`; delete lock/manifest writing and `verifyLock` |
| `orly/src/model.ts` | EDIT | delete `profileDigest`/`registryDigest`/`contentDigest`/`implementationSources` |
| `orly/src/verify.ts` | EDIT | idempotence + root-render currency; evidence drops `registry_digest` |
| `orly/src/{cli,model,render,references,repository,verify}.test.ts` | EDIT | follow the surviving surfaces |
| `orly/registry.json` | EDIT | packs keep extensions+façade pointer; `managed_files` lists removed; render.stable fail fixture swapped |
| `orly/profiles/*.json` | EDIT | keep `packs` + `commands{}` (the Model C command surface); nothing else |
| `orly/fixtures/tampered-lock.json` → `orly/fixtures/unclosed-pack-block.md` | DELETE + CREATE | genuine render-failure fail fixture replaces the ledger one |
| `orly/schemas/ruleset-lock.schema.json` DELETE; `orly/schemas/evidence.schema.json` | EDIT | ledger schema gone; evidence drops `registry_digest` |
| `orly/generated/**` | DELETE | root `AGENTS.md` becomes the one render target; homes relink to it |
| `AGENTS.md` | EDIT | regenerated: digest-free header; lifecycle prose from §5 |
| `orly/core/operating-model.md` | EDIT | lifecycle names `orly next` as driver; anchor invariant; LAND/SHIP prose-manual note |
| `.oracle/ruleset.lock`, `.oracle/profile.json`, `.oracle/managed-files.json` | DELETE | ledger artifacts (dotfiles self-copies) |
| `.agents-comprehension-signoff`, `.agents-invariance-signoff` | DELETE | zero references anywhere — orphans |
| `.githooks/pre-push` | EDIT | audit+evidence scoped to governance paths; live LLM smoke removed (manual/scheduled) |
| `audits/agents-md.md` | EDIT | reword 4 ledger rows; add Scenario 27 (engine semantics) |
| `audits/data.sh` | EDIT | `NAMED_SCENARIOS` +1 for Scenario 27 |
| `docs/TEMPLATE.md` | EDIT | add `## Transitions` append-only log section |
| `audits/spec-template.sh` | EDIT | `REQUIRED_SECTIONS` += Transitions |
| `dispatch/write_spec.md` | EDIT | name the Transitions section in Family 2 prose |
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

### §2 — Lifecycle engine (Model P)

The state machine: `PENDING → PLANNED → EXECUTING → VERIFIED → PR_READY → DONE`, plus `PARKED` reachable from any working state. Stage names are the existing vocabulary; CONFORM/REVIEW/DOCUMENT are exit criteria inside transitions, not dwelling states. State record = append-only `## Transitions` table in the active spec. v1 ends at PR_READY.

- **Dimension 2.1** — Transitions log: parse, tail-validate (`last.to` must equal observed state), append; no rewrite path exists → Test `test_transitions_append_only`
- **Dimension 2.2** — `orly status`: repo → active spec → current state → next transition's criteria with green/red per line; read-only → Test `test_status_reports_red_criteria`
- **Dimension 2.3** — `orly next`: evaluate current transition's exit criteria; all green → append transition + update spec `Status:` field; any red → print each failing criterion (name, command, one output line), exit 1, no append → Test `test_next_halts_on_red`
- **Dimension 2.4** — exit criteria wiring: built-ins (spec-template gate clean, zero `[?]` in spec, clean-or-accepted tree, non-default branch, Dimensions marked DONE, changelog-or-exemption, branch pushed) + profile `commands{}` groups (`conform`, `verify.*`) per the criteria table in Interfaces → Test `test_criteria_per_transition`
- **Dimension 2.5** — `orly check <state>`: read-only, exit-code-only; safe for Continuous Integration (CI) later → Test `test_check_readonly`

### §3 — Escape hatches (owner authority, recorded)

Exactly three. Each requires a non-empty `--reason`, appends a log entry visible in the Pull Request (PR) diff, and never marks a failed command green — an OVERRIDE entry is distinct from a pass.

- **Dimension 3.1** — `orly override <criterion> --reason` appends OVERRIDE row; `next` treats that criterion as satisfied-by-override → Test `test_override_recorded_not_green`
- **Dimension 3.2** — `orly park --reason` / `orly reset --to <state> --reason` append rows; empty reason refused → Test `test_park_reset_require_reason`

### §4 — Thin distribution (Model F)

One render target: dotfiles root `AGENTS.md`. Agent homes symlink to it. Consumers carry no orly-managed files. **Implementation default:** provenance moves to sync-commit messages; the generated header names only the profile — render becomes a pure function of (sources, profile), so byte-diff currency checks never see phantom drift.

- **Dimension 4.1** — `orly sync --global` renders root `AGENTS.md` + relinks homes; `orly/generated/` deleted → Test `test_render_targets_root`
- **Dimension 4.2** — ledger machinery deleted: lock/manifest writing, `verifyLock`, digest functions, `sync <repo>`/`adopt` verbs, replacement/adoption guards → Test `grep_zero_ledger_symbols`
- **Dimension 4.3** — registry slims (packs: extensions + façade pointer only); render.stable fail fixture = `unclosed-pack-block.md`; schemas updated → Test `test_validate_slim_registry`
- **Dimension 4.4** — `orly verify --all` = per-profile double-render idempotence + root-render currency; `orly doctor` = home links + root currency → Test `test_verify_currency`

### §5 — Prose + enforcement retarget

- **Dimension 5.1** — operating model: lifecycle section names `orly next` as the sole driver; anchor invariant sentence added; LAND/SHIP recorded as prose-manual stages pointing at v2; regenerated `AGENTS.md` ≤ 32,768 bytes → Test `audit_size_and_headers`
- **Dimension 5.2** — `.githooks/pre-push`: `make audit` + evidence only when the pushed range touches governance paths; live `llmevals` removed from hooks (manual `make llmevals` stays) → Test `grep_prepush_scoped`
- **Dimension 5.3** — questionnaire: 4 ledger rows reworded; Scenario 27 (engine semantics: what advances, what halts, how overrides record) + `NAMED_SCENARIOS` parity → Test `audit_named_scenarios`
- **Dimension 5.4** — `docs/TEMPLATE.md` gains `## Transitions`; `audits/spec-template.sh` requires it (staged scope); `ORLY_ARCHITECTURE.md` + `README.md` rewritten → Test `audit_spec_gate_transitions`

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

Transitions row:  | {ISO ts} | FROM→TO | {agent|indy} | green | OVERRIDE(<criterion>) |
Exit codes: 0 advanced/green · 1 criteria red · 2 usage or state corruption

Exit criteria per transition (fixed graph; profile commands{} supply the runnable rows):
  PENDING→PLANNED    spec-template gate clean · zero "[?]" · Product Clarity present
  PLANNED→EXECUTING  clean-or-accepted tree · non-default branch · profile resolves
  EXECUTING→VERIFIED conform commands green · verify.* commands green · touched
                     Dimensions marked DONE
  VERIFIED→PR_READY  changelog-or-exemption · docs updated per surface checklist ·
                     Dead Code Sweep clean · branch pushed · spec-template gate clean
```

## Failure Modes

| Mode | Cause | Handling (system response + what the caller observes) |
|------|-------|--------------------------------------------------------|
| Red criterion | any exit-criterion command fails | print criterion + command + one output line; exit 1; no log append |
| Log tail mismatch | spec edited outside the engine | exit 2; print expected vs observed state; no append |
| No active spec | `next` outside a spec-bearing worktree | exit 2; name `kishore-spec-new` as the fix |
| Profile missing command group | profile lacks `conform`/`verify.*` | exit 2 naming the profile file; never a crash/stack |
| Empty override reason | `--reason ""` or omitted | refuse, exit 2; nothing appended |
| Broken home link | symlink target moved/deleted | `orly doctor` red naming the link and target |
| Consumer gate path absent | dotfiles not at `ORLY_ROOT` on a machine | consumer `make` fails loudly printing the expected path (documented in harness.mk) |
| Override of a load-bearing criterion | owner records OVERRIDE | allowed; row visible in PR diff; never rendered as green |

## Invariants

1. Anchor — no transition is appended unless every exit criterion is green or carries its own OVERRIDE row — enforced by `lifecycle.ts` having a single advance path.
2. The Transitions log is append-only — no rewrite function exists; tail-validation rejects divergence (exit 2).
3. Render purity — `render(sources, profile)` twice → byte-identical — enforced by the retained idempotence check in `orly verify --all`.
4. Zero ledger artifacts — no lock/digest/manifest files or symbols anywhere — enforced by deletion + rubric R4 grep.
5. `AGENTS.md` ≤ 32,768 bytes — enforced by `audits/agents-md.sh` check 16 (unchanged).
6. Overrides carry a non-empty reason — argument validation + negative test.

## Metrics & Observability

| Metric / event | Owner | Fires when | Properties allowed | Privacy guard | Test proof |
|----------------|-------|------------|--------------------|---------------|------------|
| not applicable — no product/operator signal changes; `orly status`/`next` output is the operator surface | — | — | — | — | — |

## Transitions

| Timestamp | From → To | Actor | Verdict |
|---|---|---|---|
| Jul 27, 2026: 04:35 PM | PENDING → IN_PROGRESS | agent | CHORE(open) — hand-run; the engine this spec builds does not exist yet |

## Test Specification (tiered)

| Dimension | Tier | Test | Asserts (concrete inputs → expected output) |
|-----------|------|------|---------------------------------------------|
| 1.1 | gate (grep) | `grep_rest_guide_ported` | banned-vocab grep → 0 hits; both exception blocks present with markers |
| 1.2 | gate (grep) | `grep_verify_tiers_ported` | coverage-lane + integration-root headings present in source |
| 2.1 | unit | `test_transitions_append_only` | append twice → two rows; tampered tail → exit 2, no append |
| 2.2 | unit | `test_status_reports_red_criteria` | fixture with failing verify → status lists that criterion red, exits 0 |
| 2.3 | integration | `test_next_halts_on_red` | failing conform command → exit 1, no new row, output names criterion + command |
| 2.3 | e2e (subprocess) | `test_e2e_full_walk` | fixture repo walks PENDING→PR_READY via spawned `bin/orly next` ×4; final log row PR_READY |
| 2.4 | unit | `test_criteria_per_transition` | each transition evaluates exactly its declared criteria set |
| 2.5 | unit | `test_check_readonly` | `check VERIFIED` on red fixture → exit 1; no file mutated |
| 3.1 | unit | `test_override_recorded_not_green` | override then next → advance; log row says OVERRIDE(criterion), not green |
| 3.2 | unit | `test_park_reset_require_reason` | empty reason → exit 2, log unchanged; with reason → row appended |
| 4.1 | unit | `test_render_targets_root` | render writes root `AGENTS.md`; no `.oracle/` outputs; homes relink |
| 4.2 | gate (grep) | `grep_zero_ledger_symbols` | word-boundary greps for deleted symbols → 0 matches (Dead Code Sweep) |
| 4.3 | unit | `test_validate_slim_registry` | validate passes slim registry; fail fixture `unclosed-pack-block.md` makes render throw |
| 4.4 | unit | `test_verify_currency` | stale root `AGENTS.md` → verify red naming the file; regenerate → green |
| 5.1–5.4 | gate | `make audit` | full chain green: size cap, scenarios parity, spec gate incl. Transitions |
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
| R9 | Spec corpus clean incl. Transitions rule (§5) | `bash audits/spec-template.sh --all` | exit 0 | P0 | |
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

- LAND/SHIP machine states (`pr-ready → landed → deployed → observed`) — v2 spec; prose-manual until then.
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

- **Consults** — Architecture: Jul 27, 2026 session — Opus 5 review + Fable 5 subagent audit (ledger self-refuting; dual delivery via global symlink; downstream-first fixes) + external ChatGPT verdict (P+F+C; coarse states; three escape hatches; anchor invariant on movement). Indy decisions: process-as-code foundation; distribution ceremony dies; stage vocabulary retained.
- **CHORE(open) deviation — no sibling worktree; branch cut in the main checkout.** The agent-home symlinks (`~/.claude/CLAUDE.md` and siblings) must resolve to a path that survives the branch, and §4.1 retargets them at `~/Projects/dotfiles/AGENTS.md`. A sibling worktree would either link agents at a directory removed post-merge or leave them on stale rules. Consequence accepted: a new agent session started mid-EXECUTE reads partially-rebuilt rules. Same-tree matches the operating model's stated default.
- **Metrics review** — no analytics/funnel playbook update required: internal governance tooling, no product signal.
- **Skill-chain outcomes** — (populated at VERIFY/CHORE(close)).
- **Deferrals** — none.
