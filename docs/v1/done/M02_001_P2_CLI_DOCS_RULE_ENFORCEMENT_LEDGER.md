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

# M02_001: Rule Enforcement Ledger — every rule doc reports what is enforced, what fires, and what is prose

**Prototype:** v1.0.0
**Milestone:** M02
**Workstream:** 001
**Date:** Aug 16, 2026
**Status:** DONE
**Priority:** P2 — governance tooling; no customer surface, but it converts "is my LOGGING_STANDARD adhered to?" from a model's claim into a committed scoreboard
**Categories:** CLI, DOCS
**Batch:** B1 — no parallel siblings
**Branch:** `feat/m02-rule-ledger` — in the main checkout at `~/Projects/dotfiles`; dotfiles takes no worktree (`dispatch/lifecycle.md`)
**Test Baseline:** `unit=51` (51 pass / 0 fail across 12 files, `cd orly && bun test src`); dispatch-eval fixtures `12 passed, 0 failed`
**Depends on:** none (M01_001 DONE — the gates engine and thin distribution this builds on)
**Provenance:** LLM-drafted (Claude Fable 5, Aug 16, 2026) — grounded in the measured corpus: 332 normative clauses across the docs tier carry 8 tags; `audits/logging.sh` enforces 2 of LOGGING_STANDARD's 34; zero mechanical DOC READ verification exists
**Canonical architecture:** `docs/DISPATCH_ARCHITECTURE.md` §6 (façade pairs, tag grammar, coverage audit) — this spec extends that model from `dispatch/` into the `docs/` rule tier

---

## Overview

**Goal (testable):** `make audit` goes red when `docs/RULE_ENFORCEMENT.md` is stale, and that committed scoreboard reports — for every registered rule doc — which of its rules a script decides and which script decides each, how many are agent-judged or acknowledged-unenforced, how much of the document has been classified at all, and whether anything can trigger a read of it; and pre-commit turns the `📖 DOC READ` proof-line from self-report into a set comparison.
**Problem:** Nobody can answer "is LOGGING_STANDARD adhered to, and which clauses?" without reading the audit source by hand. The `dispatch/` tier is fully audited (tag ↔ check ↔ fixture ↔ probe coherence), but the `docs/` rule tier sits outside every coverage glob: hundreds of MUST/NEVER clauses with no enforcement class, no report, and no signal when a doc's trigger goes dead. The DOC READ proof-line is emitted by the model about itself and compared against nothing. M01's close demonstrated the cost: a P0 length violation sat in shipped code for weeks because no mechanism forced the check to run.
**Solution summary:** One new leaf audit (`audits/rule-ledger.sh`) with two read-only modes — clause census (including the structural trigger-scope check) and scoreboard currency check — plus a generated, committed scoreboard (`docs/RULE_ENFORCEMENT.md`) whose staleness fails `make audit`; one new helper (`audits/doc-read.sh`) that a `PostToolUse` hook feeds and pre-commit consults, so a session that edits source without reading its triggered docs goes red mechanically; and a pilot tagging pass over `docs/LOGGING_STANDARD.md` proving the clause-class grammar on the doc that motivated the work.

## PR Intent & comprehension handshake

- **PR title (eventual):** `feat(audits): rule-enforcement ledger + mechanized doc-read check`
- **Intent (one sentence):** Every rule document reports, in a committed artifact, how much of it is machine-enforced versus prose — and the claim "I read the triggered docs" becomes checkable — so governance drift is visible the commit it happens.
- **Handshake** — the implementing agent fills this at PLAN, before EXECUTE: restate the Intent in its own words and list `ASSUMPTIONS I'M MAKING: …`. A mismatch between the restatement and the Intent above → STOP and reconcile before any edit.

## Implementing agent — read these first

1. `evals/dispatch/coverage.sh` — the tag-extraction idiom (`grep -oE` + `sed`, no awk for macOS portability) and the seven-check coherence shape this ledger mirrors for the docs tier. Originally "do not modify it"; superseded at review — it now sources the ledger library so one grammar serves both tiers.
2. `audits/spec-template.sh` — the house leaf-audit shape: mode flags, `fail()`/`ok()` reporting, `git ls-files` scoping, exit-code discipline.
3. `docs/DISPATCH_ARCHITECTURE.md` §6 — the `[DETERMINISTIC → CODE]` / `[JUDGMENT → CODE]` tag grammar this spec extends with an `[UNENFORCED → reason]` class.
4. `.githooks/pre-commit` + `.claude/settings.json` — the two wiring points: pre-commit gains the doc-read check; settings gains the `PostToolUse` Read hook.
5. `orly/src/verify.ts` (root-render currency) — the regenerate-and-byte-compare pattern the scoreboard currency check reuses in shell.

## Files Changed (blast radius)

| File | Action | Why |
|------|--------|-----|
| `audits/rule-ledger.sh` | CREATE | §1–§3 census + scoreboard write/check — one script, mode-flagged, ≤350 lines |
| `audits/rule-ledger-lib.sh` | CREATE | shared extractors (clause regex, tag parse, glob map) sourced by the leaf — keeps both under the length cap |
| `audits/doc-read.sh` | CREATE | §4 `log` (hook target, appends JSON Lines (JSONL)) and `check` (pre-commit set comparison) |
| `docs/RULE_ENFORCEMENT.md` | CREATE | §3 generated scoreboard — census table, one row per registered rule doc; currency-checked, never hand-edited |
| `docs/LOGGING_STANDARD.md` | EDIT | §5 pilot: every normative clause gains a class tag; zero prose changes beyond tags |
| `.claude/settings.json` | EDIT | §4 `PostToolUse` hook on Read → `audits/doc-read.sh log` |
| `.githooks/pre-commit` | EDIT | §4 invoke `doc-read.sh check` when source files are staged; `make audit` moves out to pre-push on Indy's call (see Discovery) |
| `Makefile` | EDIT | `audit` target gains `rule-ledger.sh --check`; new `ledger` convenience target prints the census |
| `evals/dispatch/coverage.sh` | EDIT | reads the tag grammar from `rule-ledger-lib.sh` instead of its own copy (the spec's "do not modify it" is superseded by Indy's dedup call — Discovery) |
| `evals/ledger/run.sh` | CREATE | fixture-driven pass+fail cases for every deterministic behaviour below |
| `evals/ledger/lib.sh` | CREATE | fixture builders + reporting, split from the runner at the length rule's "ceiling, not a budget" — the cases read as a list of behaviours |
| `evals/ledger/doc_read_cases.sh` | CREATE | §4 read-record cases; split at 345/350 lines, and they are a separate concern (each needs a real git repository, the census cases do not) |
| `docs/DISPATCH_ARCHITECTURE.md` §6.6 | EDIT | the docs-tier extension: `[UNENFORCED → reason]`, block-tag scope, what counts as a clause, registry location |
| `audits/agents-md.md` | EDIT | Scenario 28 grading the ledger semantics + recorded doc-read (rule-extension protocol step 2) |
| `audits/data.sh` | EDIT | scenario-count parity for the new question |
| `orly/core/operating-model.md` | EDIT | §4b — DOC READ GATE requires the recorded read; three justification tails trimmed to fit the 32,768-byte cap |
| `AGENTS.md` (generated) | EDIT | re-rendered by `orly sync --global`; all four agent homes carry §4b |
| `orly/src/gates.test.ts` | EDIT | the end-to-end walk carries a 30s timeout — bun's 5s default reds pre-commit on a loaded machine while every assertion still holds; Indy-approved carve-out, see Discovery |

## Applicable Rules

- **`~/Projects/dotfiles/docs/greptile-learnings/RULES.md`** — FLL (two new shell files stay ≤350; split via the `-lib` sibling by design), UFS (mode strings, glob patterns, report headings as named constants; JSONL field names shared between `log` and `check` verbatim), NDC (no speculative modes — every flag has a caller in Makefile, hooks, or evals), ORP (no orphans: every created file is invoked by audit, hook, or eval).
- `dispatch/write_shell.md` — all four shell files: quoted expansions, array arguments, no `eval`, macOS Bash 3.2 compatibility (no associative arrays; mirror coverage.sh's grep/sed idiom).
- `dispatch/write_any.md` — length pre-check before each Write; the 350 cap is a ceiling, not a budget.
- `dispatch/edit_rules.md` — the diff touches `audits/`, `Makefile`, `.githooks/`, `.claude/settings.json`: full governance chain (`make audit`, questionnaire, evidence) per commit; no agent override exists.
- `dispatch/write_spec.md` + `~/Projects/dotfiles/docs/TEMPLATE.md` — this spec.

## Applicable Gates

| Gate | Fires? | Satisfaction strategy |
|------|--------|-----------------------|
| ZIG GATE | no — no `*.zig` touched | — |
| PUB / Struct-Shape | no — shell only, no TS surface | — |
| File & Function Length (≤350/≤50/≤70) | yes | ledger logic split across leaf + lib at design time; functions named per step, ≤50 |
| UFS (repeated/semantic literals) | yes | mode names, JSONL keys, report column headings → named constants at top of each script |
| UI Substitution / DESIGN TOKEN | no — no UI surface | — |
| LOGGING / LIFECYCLE / ERROR REGISTRY / SCHEMA | no — governance tooling, no product logging surface | — |
| SPEC TEMPLATE GATE | yes — this file | `audits/spec-template.sh --staged` clean before each commit |
| edit_rules (no override) | yes — entire diff | audit + questionnaire + evidence per `dispatch/edit_rules.md` |

## Prior-Art / Reference Implementations

- **Reference:** `evals/dispatch/coverage.sh` — the proven tag→check→fixture coherence audit; the ledger is its docs-tier sibling, reusing the extraction idiom rather than the file (coverage.sh stays dispatch-scoped and untouched).
- **Reference:** `orly verify` root-render currency — regenerate-to-temp, byte-compare, red-with-fix-command; the scoreboard check is the same shape in shell.
- **Reference:** `audits/logging.sh` — leaf audit arg-parsing and OK/FAIL/INFO output conventions.

## Sections (implementation slices)

### §1 — Clause census (`--census`) — DONE

A registry array in `rule-ledger-lib.sh` names the docs-tier rule files (LOGGING_STANDARD, REST_API_DESIGN_GUIDELINES, SCHEMA_CONVENTIONS, DOCUMENTATION_RULES, LIFECYCLE_PATTERNS, CHANGELOG_VOICE, VERIFY_TIERS, greptile-learnings/RULES.md). Census emits one row per entry: normative-clause count (keyword-line heuristic: MUST / NEVER / ALWAYS / Forbidden / Required / SHALL), tag counts by class, and untagged remainder. Counts inform; they never gate. **Implementation default:** the parity guard is the only census red — a `docs/*.md` cited as a rule read by any `dispatch/*.md` façade but absent from the registry (architecture docs and TEMPLATE.md sit on an explicit exclude list).

- **Dimension 1.1** — DONE — census prints exactly one row per registered doc, machine-parseable columns → Test `ledger_census_rows`
- **Dimension 1.2** — DONE — an unregistered-but-cited doc turns census red naming the doc and the registry file → Test `ledger_census_parity_red`
- **Dimension 1.3** — DONE — the `[UNENFORCED → reason]` tag class parses and counts separately from untagged → Test `ledger_unenforced_class`

### §2 — Trigger scope (built, then cut back to the half that gates)

Shipped as a `--reachability` mode: derive each façade's globs from its `dispatch_init` line, replay 50 commits, report fire counts. **Removed before the PR on Indy's review call** (Discovery, Aug 16). It had one consumer — a `make ledger` target a human types — gated nothing, and its output is history-relative, so it could never enter the tree-pure scoreboard. Roughly 90 lines of script plus three evals bought a curiosity.

The half worth keeping answers from the tree and now gates inside `--census`: a façade executable that declares no scope carries rules no diff can ever reach.

- **Dimension 2.1** — REMOVED — fire counts over history. Nothing consumed them; "has this fired lately" depends on what happened to get committed recently, not on whether the rule can fire at all.
- **Dimension 2.2** — DONE — a façade whose `.sh` yields no derivable globs is a structural red naming the file, checked by the census → Test `ledger_census_facade_scope_red`

### §3 — Committed scoreboard (`--write` / `--check`) — DONE

`--write docs/RULE_ENFORCEMENT.md` renders the census as a markdown table plus a legend; `--check` regenerates to a temp file and byte-compares, red with the exact fix command. Wired into `make audit`.

- **Dimension 3.1** — DONE — `--write` is deterministic: two runs on the same tree are byte-identical; no timestamps, no commit hashes → Test `ledger_write_deterministic`
- **Dimension 3.2** — DONE — editing a registered doc without regenerating turns `make audit` red; regenerating clears it → Test `ledger_check_currency`

### §4 — Mechanized doc-read record — DONE

`audits/doc-read.sh log <path>` appends `{ts, path}` JSONL rows to `.git/orly/doc-reads.jsonl` (repo-local, never committed); a `PostToolUse` hook on the Read tool feeds it. `check` computes the expected doc set for staged source files from the same glob map §2 uses, keeps logged rows newer than the HEAD commit timestamp, and reds on the missing set. **Implementation default:** log absent (agent without hook support — codex, amp, opencode) → one 🟠 warn line, exit 0; partial mechanization stated honestly beats a false red. The `📖 DOC READ` proof-line remains required in chat — the log is evidence, not a replacement.

**Implementation default — expected set is façade pages only.** A staged file expects `dispatch/<stem>.md` for every façade whose `dispatch_init` scope it matches. The rule docs those façades delegate to (`SCHEMA_CONVENTIONS` from `write_sql`, `REST_API_DESIGN_GUIDELINES` from `write_http`) are deliberately excluded: their reads are conditional on the diff's shape, so requiring them would red honest work. Widening the set is follow-up work, once the narrow set has run clean for a milestone.

- **Dimension 4.1** — DONE — `log` appends valid JSONL; concurrent appends never corrupt (append-only, one line per call) → Test `ledger_readlog_append`
- **Dimension 4.2** — DONE — `check` red lists exactly the unread triggered docs; green when each was read at its current content; exit 0 + warn when the log file is absent → Tests `ledger_readlog_check_matrix`, `ledger_readlog_content_keyed`

**Validity is keyed to content, not to a clock** — changed after dogfooding, which is also how it was found. The first cut counted a read as valid if it happened since the HEAD commit. That is wrong in both directions: it forces a re-read of an unchanged façade every time an unrelated commit lands (it blocked three of this milestone's own commits), and it keeps counting a read taken *before* the façade was edited, which is the case that actually matters. `log` now records the document's blob hash and `check` compares it to the file on disk: unchanged document, earlier read still counts; edited document, every prior read is void the same second.
- **Dimension 4.3** — DONE — pre-commit invokes `check` only when staged files match source extensions → Test `ledger_precommit_wiring`

### §4b — The record works in every runtime, not just the hooked one — DONE

Folded in mid-milestone on Indy's call (Discovery, Aug 16). A `PostToolUse` hook binds Claude Code alone; codex exposes only a turn-ended `notify`, amp has no tool-event surface, and opencode's plugin system is unconfigured — so three of four runtimes would commit unchecked while the scoreboard claimed the read was mechanized. The DOC READ GATE therefore requires the read to be **recorded**, not merely claimed: `bash audits/doc-read.sh log <path>`, which any runtime can run and Claude Code's hook runs automatically. `check` is unchanged — a hook-written row and a command-written row are the same line in the same file.

- **Dimension 4.4** — DONE — the rendered `AGENTS.md` (and therefore all four agent homes) carries the recorded-read requirement → Test `ledger_doc_read_command_documented`
- **Dimension 4.5** — DONE — no file on the enforcement path (`audits/doc-read.sh`, `.githooks/pre-commit`, the ledger scripts) names a runtime, its env vars, or its payload shape; that coupling is confined to per-runtime configuration, which is deletable without touching enforcement → Test `ledger_doc_read_runtime_neutral`

**Why 4.5 is a test and not a promise** (Indy, Aug 16: *"I dont want this to tied to any tool, since they would keep removing features"*). Vendors add and remove hook APIs. A read hook is therefore treated as an accelerator, never a dependency: delete `.claude/settings.json`'s Read hook entirely and the gate behaves identically — the agent runs `bash audits/doc-read.sh log <path>`, the record is the same line in the same file, `check` cannot tell the difference. The eval enforces the boundary so the coupling cannot creep back in a later commit; its negative control (injecting `CLAUDE_PROJECT_DIR` into the hook) was confirmed to fail the suite.

### §5 — Pilot tagging: LOGGING_STANDARD — DONE

Every normative clause in `docs/LOGGING_STANDARD.md` gains a class tag: `[DETERMINISTIC → LOG]` where `audits/logging.sh` enforces it, `[DETERMINISTIC → TODO-CHECK]` where mechanizable but unwired, `[JUDGMENT → …]` where only an agent can decide, `[UNENFORCED → reason]` for the acknowledged rest. Prose otherwise untouched. This proves the grammar on the doc whose 2-of-34 ratio motivated the milestone; the remaining corpus is deliberately follow-up work, one doc per PR.

- **Dimension 5.1** — DONE — census row for LOGGING_STANDARD reports `untagged=0` → Test `ledger_pilot_fully_classified`

**What the pilot changed about §1's counter.** Tagging a real document proved a line-per-tag model wrong twice, and both fixes landed here rather than being worked around in prose: (1) markdown table rows and headings are no longer counted as clauses — `| ts_ms | u64 | always | … |` is a column value, and a heading is a title; (2) a tag alone on its line now covers every clause under it until the next heading, the same block grammar `dispatch/*.md` already uses, so a paragraph-shaped rule takes one tag instead of one per line. Verified against the already-tagged tier: `dispatch/write_any.md` reads back 6 deterministic clauses from its block tags → Test `ledger_block_tag_scope`.

## Interfaces

```
audits/rule-ledger.sh --census                 one row per registered rule doc; exit 0, or 1 on parity red
audits/rule-ledger.sh --write <file>           render scoreboard (the only mode that writes)
audits/rule-ledger.sh --check                  regenerate + byte-compare committed scoreboard; exit 1 stale
audits/doc-read.sh log <path>                  append {ts, path} JSONL row to .git/orly/doc-reads.jsonl
audits/doc-read.sh check                       staged-source expected-docs vs logged reads; exit 1 on missing,
                                               exit 0 + warn when no log exists
Exit codes: 0 clean · 1 violation/stale · 2 usage. Census and check write
nothing; scoreboard rows:
| doc | enforced by (CODE → script) | judged | acknowledged | classified | trigger |
`enforced by` resolves each DETERMINISTIC code to the leaf audit a dispatch
`.sh` runs for it, so a code that loses its helper stops claiming enforcement
the same commit. All tree-derived — the file reproduces from a checkout.
```

## Failure Modes

| Mode | Cause | Handling (system response + what the caller observes) |
|------|-------|--------------------------------------------------------|
| Read-log absent | agent runtime has no hook support | `check` prints one 🟠 warn naming the limitation, exit 0 — never a false red |
| Stale scoreboard | doc edited, `--write` not rerun | `make audit` red printing the exact regenerate command |
| Census overcount | keyword appears in an example block | tolerated — counts inform, never gate; legend states the heuristic |
| Zero-fire false alarm | façade for a dormant surface, or doc younger than the window | 🟠 warn only; human dispositions it |
| Renamed/deleted rule doc | registry points at a missing path | census structural red naming the path and the registry array |
| Hook fires on out-of-repo Read | agent reads an external file | `log` drops paths outside the repo root silently |
| Concurrent sessions | two agents appending | append-only JSONL, one write per call — last-writer order is irrelevant to `check` |
| Detached HEAD at check | worktree mid-operation | HEAD commit timestamp still resolves; behaviour unchanged |

## Invariants

1. Only `--write <file>` mutates anything; the census and both check modes leave `git status` byte-identical — enforced by an eval that diffs status before/after every mode.
2. The committed scoreboard is a pure function of the working tree — enforced by the double-`--write` byte-compare eval.
3. Clause counts never fail a build; only structural conditions red (parity miss, missing path, no derivable globs, stale scoreboard) — enforced by exit-code fixture matrix.
4. `doc-read.sh check` cannot red without a read-log present — enforced by the absent-log fixture.

## Metrics & Observability

| Metric / event | Owner | Fires when | Properties allowed | Privacy guard | Test proof |
|----------------|-------|------------|--------------------|---------------|------------|
| not applicable — internal governance tooling; the scoreboard file is the operator surface | — | — | — | — | — |

## Test Specification (tiered)

| Dimension | Tier | Test | Asserts (concrete inputs → expected output) |
|-----------|------|------|---------------------------------------------|
| 1.1 | gate (fixture) | `ledger_census_rows` | row count == registry length; columns parse |
| 1.2 | gate (fixture) | `ledger_census_parity_red` | fixture façade citing an unregistered doc → exit 1, doc named |
| 1.3 | gate (fixture) | `ledger_unenforced_class` | fixture doc with `[UNENFORCED → x]` → counted as unenforced, not untagged |
| 2.1 | gate (repo) | `ledger_reachability_counts` | `write_any` fire count > 0 over real history |
| 2.2 | gate (fixture) | `ledger_reachability_structural_red` | glob-less façade fixture → exit 1 naming the file |
| 3.1 | gate (repo) | `ledger_write_deterministic` | two `--write` runs → `diff` empty |
| 3.2 | gate (fixture) | `ledger_check_currency` | mutate doc copy → `--check` exit 1; regenerate → exit 0 |
| 4.1 | gate (fixture) | `ledger_readlog_append` | two `log` calls → 2 valid JSONL rows |
| 4.2 | gate (fixture) | `ledger_readlog_check_matrix` | missing-read → exit 1 listing docs; all-read → exit 0; no log → exit 0 + 🟠 |
| 4.3 | gate (grep) | `ledger_precommit_wiring` | `.githooks/pre-commit` carries the guarded invocation |
| 5.1 | gate (repo) | `ledger_pilot_fully_classified` | LOGGING_STANDARD census row shows `untagged=0` |
| 4.2c | gate (fixture) | `ledger_readlog_content_keyed` | read → edit façade → check exit 1; re-read → exit 0 |
| 4.4 | gate (repo) | `ledger_doc_read_command_documented` | rendered `AGENTS.md` names `doc-read.sh log` |
| 4.5 | gate (repo) | `ledger_doc_read_runtime_neutral` | no enforcement file names a runtime; negative control confirmed |
| 5.1b | gate (repo) | `ledger_block_tag_scope` | `dispatch/write_any.md` yields >0 deterministic clauses from block tags |
| contract | gate (repo) | `ledger_usage_exit_codes` | every misuse of both scripts exits 2; `--help` exits 0 |
| contract | gate (fixture) | `ledger_reachability_zero_fire_warns` | dormant scope → 🟠, exit 0 (never a red) |
| contract | gate (fixture) | `ledger_write_aborts_on_missing_doc` | render abort → exit 1 **and** no file written |
| contract | gate (fixture) | `ledger_trigger_uncited` | `uncited` and `latent` reported apart |
| review | gate (fixture) | `ledger_write_locale_stable` | multi-code rows identical under `LC_ALL=C` and `en_US.UTF-8` |
| review | gate (fixture) | `ledger_readlog_escapes_path` | `we"ird.md` writes parseable JSON |
| review | gate (fixture) | `ledger_readlog_fails_closed` | an unhashable path records no row |
| regression | gate (repo) | `make audit` | existing chain stays green with the new rows added |

## Acceptance Rubric (single scoring surface)

| # | Criterion (observable outcome) | Verify (copy-paste) | Expected | Priority | Graded (VERIFY) |
|---|--------------------------------|---------------------|----------|----------|-----------------|
| R1 | Ledger eval suite green (§1–§5) | `bash evals/ledger/run.sh` | exit 0 | P0 | ✅ `23 passed, 0 failed` (exit 0) |
| R2 | Diff stays inside Files Changed | `git diff --name-only origin/master...HEAD` | 0 paths missing from the Files Changed table | P0 | ✅ 19 paths, all in the table (the spec file itself excepted) |
| R3 | Scoreboard exists and is current (§3) | `bash audits/rule-ledger.sh --check` | exit 0 | P0 | ✅ exit 0 — `🟢 docs/RULE_ENFORCEMENT.md matches the tree` |
| R4 | Census reports the pilot fully classified (§5) | `bash audits/rule-ledger.sh --census \| grep 'LOGGING_STANDARD'` | contains `untagged=0` | P0 | ✅ `untagged=0` |
| R5 | Scoreboard names the enforcing script (§3) | `grep 'LOGGING_STANDARD' docs/RULE_ENFORCEMENT.md` | contains `` `LOG` `` → `` `logging.sh` `` | P0 | ✅ `` `LOG` `` → `` `logging.sh` `` |
| R6 | Governance audit green with new rows | `make audit` | `ALL CHECKS PASSED` | P0 | ✅ `ALL CHECKS PASSED` + `DISPATCH COVERAGE: ALL CHECKS PASSED` (exit 0) |
| R7 | Read-only modes write nothing (§1,§2,§3-check,§4-check) | `git status --porcelain=v1 -uall` before/after each mode | identical output | P0 | ✅ status identical before/after census, check, doc-read check |
| S7 | No secrets | `gitleaks detect` | exit 0 | P0 | ✅ `no leaks found` |
| S8 | No oversize source file | `git diff --name-only origin/master...HEAD \| grep -E '\.(sh\|ts)$' \| xargs -I{} sh -c 'wc -l "{}" 2>/dev/null' \| awk '$1>350'` | no output | P0 | ✅ no output (largest: doc_read_cases.sh 207) |
| S9 | Orphan sweep | every created file invoked by audit, hook, Makefile, or eval — `grep -rn 'rule-ledger\|doc-read' Makefile .githooks .claude/settings.json evals` | ≥1 caller per created script | P0 | ✅ 8 callers across Makefile, .githooks, settings.json, evals |

**Grading protocol (VERIFY):** run the Verify command verbatim; grade ONLY from its output. Graded = ✅/❌ + the one decisive output line. **Ship gate:** every row graded, every P0 ✅ → eligible for CHORE(close); any ❌ or empty cell → return to EXECUTE; a P1 ❌ ships only with an Indy-acked deferral quote in Discovery.

## Dead Code Sweep

N/A — no files deleted; no symbols removed. (S9 covers the inverse: no created file may lack a caller.)

## Out of Scope

- Tagging the remaining seven rule docs — follow-up, one doc per PR, using the grammar §5 proves.
- Grading a spec's Applicable Rules clause IDs at VERIFY ("did the named clause actually fire on this diff") — lands with the outcome-grading milestone.
- Product-repo rollout of the doc-read hook (agentsfleet et al.) — after the mechanism proves itself here.
- Historical trend ledger / scorecard JSONL — belongs to the spec-scoring milestone.
- The `audits/ufs.sh` test-scope contradiction (questionnaire 4.7c says test fixtures are in UFS scope; `ufs.sh` exempts string-dup in test files) — needs Indy's fix-direction call before any edit; recorded here so it is not lost.
- De-hardcoding the 151 `~/Projects/dotfiles` path literals — belongs to the orly packaging milestone.

---

## Product Clarity (authoring record)

1. **Successful user moment** — Indy opens `docs/RULE_ENFORCEMENT.md` and reads, per rule doc, exactly how many clauses are machine-enforced, judgment, acknowledged-unenforced, or untagged — the question "is LOGGING_STANDARD adhered to?" answered by a committed table instead of an agent's assurance.
2. **Preserved user behaviour** — `make audit` semantics unchanged for existing checks; DOC READ proof-lines still print; no gate weakens; coverage.sh untouched.
3. **Optimal-way check** — direct. Known gap: the clause census is a keyword heuristic, not a semantic parse — acceptable because counts inform and never block; a parse would be a different cost class for marginal precision.
4. **Rebuild-vs-iterate** — iterate: new leaf audits beside existing ones, same house idiom. No determinism is traded; the scoreboard adds a determinism surface.
5. **What we build** — two audit scripts + lib, one generated scoreboard, hook + pre-commit wiring, pilot tags on one doc, a fixture-driven eval suite.
6. **What we do NOT build** — full-corpus tagging, VERIFY-time clause grading, product-repo rollout, trend storage (each named in Out of Scope with its destination).
7. **Fit with existing features** — compounds with the dispatch coverage audit (same grammar, adjacent tier) and `orly gate` (audit stays the CONFORM backbone); must not destabilize `make audit` — green at every commit.
8. **Surface order** — CLI-only; the committed markdown file is the read surface.
9. **Dashboard restraint** — the scoreboard prints counts and wiring status only; no quality scores, no adherence percentages dressed as grades.
10. **Confused-user next step** — every red prints its fix command verbatim (`bash audits/rule-ledger.sh --write docs/RULE_ENFORCEMENT.md`; registry array path for parity reds).

## Decomposition & alternatives (patch vs refactor)

- **Chosen shape:** five slices — census before reachability (the registry array is shared plumbing), scoreboard once census output is stable, doc-read independent of the first three, pilot tagging last (it consumes the finished grammar).
- **Alternatives considered:** extending `evals/dispatch/coverage.sh` to the docs tier — rejected: its seven checks encode façade-pair semantics (tag↔.sh-row↔fixture↔probe) that the docs tier doesn't have; overloading it risks the audit that already works. TypeScript-in-orly implementation — rejected for now: audits are shell by house pattern, hooks invoke shell with zero startup cost; revisit if the ledger grows query features.
- **Patch-vs-refactor verdict:** this is a **patch** (additive tooling; nothing restructured). The refactor-shaped follow-up — clause grading inside VERIFY — is named in Out of Scope, not folded in.

## Discovery (consult log)

- **Consults** — Architecture / Legacy-Design / gate-flag triage: the question asked + Indy's decision.
  - Aug 16, 2026: 03:10 PM — runtime coverage. Indy: "how will other coding editors opencode, amp, codex do that … that is my concern." Checked each runtime's real surface on this machine: codex exposes only a turn-ended `notify` (already bound to Computer Use), amp's settings carry no tool-event surface, opencode has a plugin system but no configured plugin; only Claude Code has a per-read hook. Presented three options; Indy chose the command path for all four — the DOC READ GATE requires `audits/doc-read.sh log <path>`, which every runtime can run, and the Claude hook stays as the version an agent cannot fake. Lands as §4b.
  - Aug 16, 2026: 03:05 PM — clause-count honesty (§5). Reaching `untagged=0` by tagging table rows would have put 15 meaningless tags in a rule doc, so the counter changed instead: headings and table rows stop counting as clauses, and block tags cover their section. The reader-facing number got more truthful; no gate weakened (parity and structural reds are untouched).
  - Aug 16, 2026: 02:40 PM — hook cost. Indy asked what the dotfiles pre-commit and pre-push actually run, then ruled: "make audit in pre push." Pre-commit now carries only the §4 doc-read check (one grep over the staged list, one read of a local record); the full audit stays on pre-push, where the corpus is about to reach someone else. No enforcement is lost — a push cannot skip it.
  - Aug 16, 2026: 02:05 PM — gate-flag triage, out-of-scope edit. `orly/src/gates.test.ts:158` (end-to-end gate walk) ran 5.5s–12.7s against bun's 5s default, reddening pre-commit's `make audit` while every assertion passed. Asked fix-or-defer; Indy chose "Raise that one test to 30s" over a suite-wide `bunfig.toml` default or waiting out machine load. Applied as a named constant on that one test; assertions untouched.
- **Metrics review** — none. Internal governance tooling; the Metrics table records "not applicable" and `/review` surfaced no event surface to add.
- **Skill-chain outcomes**
  - `/write-unit-test` — Change-set mode, Shell stack. Diff ledger 25/25 resolved (22 tested, 3 `won't-test`: colour-code branches, `--help` wording, the `content_hash` fallback before it was made fail-closed). Four declared-but-unasserted contracts found and pinned: the 0/1/2 exit matrix, the zero-fire warn, the write-abort, `uncited` vs `latent`. Mutation-checked 2/2 killed. Harness split to `lib.sh` at 316 lines.
  - `/write-integration-test` — not applicable, stated rather than skipped: the skill's scope is a service layer over real Postgres/Redis/HTTP, none of which this diff has. The equivalent real-I/O tier is already the eval suite — every doc-read case builds an actual git repository, stages actual files, and runs the actual hook path rather than a fake.
  - `/review` — three findings, all fixed and pinned, none deferred. (1) CRITICAL: the scoreboard claimed "pure function of the tree" but `sort` collates by locale, so `make audit`'s byte-compare would red for a contributor with a different `LC_ALL` as soon as a doc carries two codes — `LC_ALL=C` pinned, mutation-checked. (2) `doc-read.sh log` wrote invalid JSON for a legal filename containing `"` — escaped both ways. (3) `content_hash` returned a placeholder on git failure, so two failures compared equal and a deleted façade validated as read — now fails closed.
  - `kishore-babysit-prs` — runs after the PR opens.
- **Deferrals** — none. Every item in Out of Scope was scoped out at authoring time, not deferred mid-flight; the one dimension dropped after implementation (2.1, fire counts) was Indy's review call and is recorded in §2 with the reason, not carried as debt.
- **Security note** — a `GITLAB_PERSONAL_ACCESS_TOKEN` was printed to the transcript by an over-broad `env | grep` in the prior session. Indy (Aug 16, 2026): "i dont intend to rotate gitlab since its behind m private vpn" — closed, not outstanding. The GitHub token from the same leak was rotated.
