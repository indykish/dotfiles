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

# M03_001: `orly init` — one command installs the harness into any repository, on any machine, under any coding agent

**Prototype:** v1.0.0
**Milestone:** M03
**Workstream:** 001
**Date:** Aug 16, 2026
**Status:** IN_PROGRESS
**Priority:** P1 — the harness's users are engineers, and today a second engineer cannot install it without a guided walkthrough of ten manual steps; every downstream adoption is blocked behind this
**Categories:** CLI, DOCS, INFRA
**Batch:** B1 — no parallel siblings; agentsfleet adoption (M03_002) and cache-kit adoption (M03_003) are B2, sequential behind this
**Branch:** `feat/m03-orly-init` — in the main checkout at `~/Projects/dotfiles`; dotfiles takes no worktree (`dispatch/lifecycle.md`)
**Test Baseline:** `unit=52` (52 pass / 0 fail across 12 files, `cd orly && bun test src`); dispatch-eval fixtures `12 passed, 0 failed`; ledger evals `23 passed, 0 failed`
**Depends on:** M01_001 (the gates engine this packages, and the thin-distribution model §2 supersedes), M02_001 (rule ledger + `audits/doc-read.sh`, whose runtime-neutral command path §2 generalises)
**Provenance:** LLM-drafted (Claude Fable 5, Aug 16, 2026) — grounded in a measured survey of the harness and both consumer repositories: `managed_files` is declared for all 18 packs and consumed by zero lines of `orly/src/`; the literal `~/Projects/dotfiles` appears ~130 times here and 154 times in agentsfleet; cache-kit still carries M01's deferred `.oracle/` deletion, frozen since Jul 19, whose 14 vendored scripts have no invoker in any hook, target, or workflow
**Canonical architecture:** `docs/ORLY_ARCHITECTURE.md` — this spec supersedes M01_001 §4 (Model F, thin distribution), inverting the unit of installation from the machine to the repository

---

## Overview

**Goal (testable):** In a fresh git repository on a machine with no dotfiles checkout and no prepared `$HOME`, a single command materialises a working harness — committed `AGENTS.md`, the selected packs' rule files, installed hooks, and a version-pinned lock — such that `orly doctor` exits 0, `orly gate` evaluates its criteria, and no file under `~/Projects/dotfiles` is read at any point.

**Problem:** Setting a colleague up took a guided half-hour of ten manual steps, and what they ended with was weaker than described. M01_001 §4 chose Model F — one rendered `AGENTS.md` symlinked into four agent homes, with executable gates resolved from a dotfiles checkout — to buy "zero consumer sync commits". That mechanism requires a prepared `$HOME` and a checkout at a fixed path, so it delivers nothing to a colleague's laptop, a Continuous Integration (CI) runner, or a remote fleet container. The evidence is in both consumers: agentsfleet's gates run only inside a local pre-commit hook behind a `core.hooksPath` nothing verifies, and cache-kit — whose thin migration was deferred — has sat four weeks with 14 vendored gate scripts that no hook, target, or workflow ever invokes, and an `AGENTS.md` that tells a Rust crate its project name is `agentsfleet`.

**Solution summary:** Make the repository the unit of installation. Publish the engine as one versioned package whose payload is an explicit allowlist; implement `orly init` as the missing consumer of the `managed_files` source→target pairs the registry has always declared, so a repository receives its selected packs' rule files, its rendered `AGENTS.md`, its hooks, and a lock pinning the engine version and content hashes; add `orly update` so a rule change costs one command per repository rather than the manual N×M editing M01 rejected; fence Kishore's persona and the agentsfleet product surface into opt-in packs so a stranger's render is the kernel alone; and re-point every rule citation from the absolute `~/Projects/dotfiles/` anchor to the repository-relative path `init` materialised.

## PR Intent & comprehension handshake

- **PR title (eventual):** `feat(orly): repository-scoped install — orly init, packaged engine, portable rule paths`
- **Intent (one sentence):** Any engineer, on any machine, with any coding agent, gets the same enforced rules from one command instead of a half-hour walkthrough that only fully works on Kishore's laptop.
- **Handshake** — the implementing agent fills this at PLAN, before EXECUTE: restate the Intent in its own words and list `ASSUMPTIONS I'M MAKING: …`. A mismatch between the restatement and the Intent above → STOP and reconcile before any edit.

## Implementing agent — read these first

1. `docs/v1/done/M01_001_P2_CLI_DOCS_PROCESS_AS_CODE.md` §4 and its Discovery — the thin-distribution decision this spec supersedes, why the hash ledger was called self-refuting, and the Indy-acked deferral that left cache-kit half-migrated. Read it before restoring any materialisation: what returns is a single lock plus an update command, never the deleted manifest-and-digest ceremony.
2. `orly/registry.json` + `orly/src/model.ts` (`validatePack`) — `managed_files` already carries `source` → `target` for every pack and is validated but never installed. §2 implements the consumer that was designed for; do not invent a second materialisation format.
3. `~/Projects/cache-kit.rs/.oracle/` — the surviving artifact shape (`ruleset.lock` with a hash and octal mode per file, `managed-files.json`, `profile.json`). Read it for the format and for its failure modes: an irrelevant UI gate vendored into a Rust crate, dangling façade citations, and no invoker anywhere.
4. `orly/src/render.ts` + `orly/src/references.ts` — the pack-fencing grammar (`<!-- oracle-packs:start NAME -->`) and `referenceClosureErrors`, the existing proof that every path a render names exists on disk. §3 fences persona content with the former; §4 re-roots the latter at the consuming repository.
5. `audits/rule-paths.sh` (asserts the `~/Projects/dotfiles/` anchor as a required invariant and reads the live `~/.claude/settings.json` — §4 inverts both) and `.githooks/pre-commit` + `.githooks/pre-push` (the `GIT_DIR`-unsetting preamble every installed hook must keep). Read both before touching a citation or a hook.

## Files Changed (blast radius)

| File | Action | Why |
|------|--------|-----|
| `package.json` | CREATE | §1 repo-root manifest: `@indykish/orly`, version, `bin`, and the `files` allowlist that is the product boundary |
| `orly/package.json` | EDIT | §1 demoted to a workspace-internal dev manifest; version and publish fields move to the root |
| `orly/src/install.ts` | CREATE | §2 materialise a profile's packs into a target repository; the shared engine behind `init` and `update` |
| `orly/src/lockfile.ts` | CREATE | §2 `.oracle/ruleset.lock` read/write, content hashing, and the drift comparison `doctor` consumes |
| `orly/src/install.test.ts`, `orly/src/lockfile.test.ts` | CREATE | §2 unit and in-process sandbox cases |
| `orly/src/cli.ts` | EDIT | §2 register `init` and `update`; `--json` rendering; §2.8 drop the accepted-and-ignored `--global` flag |
| `orly/src/repository.ts` | EDIT | §2 agent-home linking becomes one caller of the shared installer, not the distribution model |
| `orly/src/render.ts`, `orly/src/references.ts` | EDIT | §3 core documents become pack-gated so persona can be deselected; §4 reference closure resolves against the consuming repository root |
| `orly/registry.json` | EDIT | §3 new `persona.indy` pack; `msid-ui.sh` moves out of `universal.authoring` into the surfaces that own it |
| `orly/profiles/global.json`, `dotfiles.json` | EDIT | §3 select `persona.indy` explicitly rather than inheriting it |
| `orly/profiles/kernel.json` | CREATE | §3 the stranger's profile — kernel packs only, no persona, no product surface |
| `SOUL.md` | EDIT | §3 body fenced into the `persona.indy` pack; zero prose changes |
| `orly/core/operating-model.md` | EDIT | §3 persona sections fenced; §4 the rule-path anchor doctrine rewritten repository-relative; §2.8 `--global` references dropped |
| `AGENTS.md` | EDIT | §3/§4 regenerated render (never hand-edited) |
| `audits/rule-paths.sh` | EDIT | §4 invert: assert citations resolve inside the consuming repository; drop the live-`$HOME` settings read |
| `audits/agents-md.sh`, `audits/data.sh` | EDIT | §4 new check label + scenario-count parity for the inverted anchor |
| `audits/agents-md.md` | EDIT | §4 questionnaire scenario grading the portable-path semantics (rule extension protocol step 2) |
| `.githooks/pre-commit`, `.githooks/pre-push` | EDIT | §2 become the templates `init` installs; parameterised on the package root |
| `.github/workflows/harness.yml` | CREATE | §5 the release gate for the published package — this repository only |
| `evals/install/run.sh`, `evals/install/cases.sh` | CREATE | §2/§4 sandbox proofs: fresh-repo install, idempotency, drift, update, portability greps |
| `Makefile` | EDIT | §2 `install-evals` target; `audit` gains the new eval and the packaging boundary check |
| `README.md` | EDIT | §5 the ten-step walkthrough collapses to one command; personal-machine steps move to their own optional section |
| `docs/ORLY_ARCHITECTURE.md` | EDIT | §5 record the machine-scoped → repository-scoped inversion, the lock, and what supersedes M01 §4 |

## Applicable Rules

- **`~/Projects/dotfiles/docs/greptile-learnings/RULES.md`** — **ORP** (the citation re-point in §4 is a rename across ~130 sites; blast-radius grep first, word-boundary, no path filter), **NDC** (§2.8 deletes the no-op `--global` rather than leaving it accepted-and-ignored), **NLR** (touch-it-fix-it on every file §4 re-points), **UFS** (all new path segments, lock keys, and the schema version are named constants appearing once), **FLL** (`install.ts` splits before 350 lines; materialisation and hook installation are separable), **JCL** (`--json` output is a stable structured contract, not a pretty-printer), **EMS** (every failure below names the offending path and the recovery command), **TST-NAM** (test identifiers carry no milestone number), **GLS** (installed dispatchers must not glob their own materialised copies)
- `dispatch/edit_rules.md` — fires on every edit to `orly/**`, `dispatch/`, `audits/`, and the generated `AGENTS.md`; **no agent override**. Requires `make audit`, the `audits/agents-md.md` questionnaire, live comprehension evaluation because §3 and §4 change render semantics, and generated evidence.
- `dispatch/write_ts_adhere_bun.md` — every file under `orly/src/`; TS FILE SHAPE DECISION at PLAN for `install.ts` and `lockfile.ts`.
- `dispatch/write_shell.md` — the installed hooks and `evals/install/*.sh`: quoted expansions, array arguments, temp-file cleanup, no untrusted `eval`.
- `dispatch/write_spec.md` — this file.

## Applicable Gates

| Gate | Fires? | Satisfaction strategy |
|------|--------|-----------------------|
| ZIG GATE | no — no `*.zig` in the diff | N/A |
| PUB / Struct-Shape | no — Zig-only verdict | TS FILE SHAPE DECISION covers the two new modules instead |
| File & Function Length (≤350/≤50/≤70) | yes — `install.ts` carries materialisation, hooks, and lock writing | split at authoring: `install.ts` orchestrates, `lockfile.ts` owns hashing; the hook installer moves out if `install.ts` passes 250 lines |
| UFS (repeated/semantic literals) | yes — new path and lock-key literals | named constants in one module each; `audits/ufs.sh --all` is already in `make audit` |
| UI Substitution / DESIGN TOKEN | no — no `ui/` surface | N/A |
| LOGGING / LIFECYCLE / ERROR REGISTRY / SCHEMA | no — none of those surfaces are touched | N/A |
| SPEC TEMPLATE GATE | yes — this spec | `bash audits/spec-template.sh --staged` clean before the CHORE(open) commit |
| Invariance Suite Gate (`edit_rules`) | yes — governance edit | `make audit` green, questionnaire all-YES, generated evidence, `make llmevals` matrix across all four agents before push |

## Prior-Art / Reference Implementations

- **Reference:** `~/Projects/cache-kit.rs/.oracle/` — the in-repo artifact shape from the pre-M01 materialiser: a lock carrying a hash and octal mode per managed file, alongside the resolved profile. §2 reuses that directory name and lock shape rather than inventing a second spelling, and drops what M01 correctly rejected: the separate manifest, the ruleset digest in the rendered banner, and per-repository copies with no update path.
- **Reference:** the "7 Pillars" of Command-Line Interface (CLI) developer experience (`docs/TEMPLATE.md` Prior-Art menu) — `init`/`update` align with command → handler → errors split (`cli.ts` parses, `install.ts` is a pure handler returning a result), handler purity (no `console.log` or `process.exit` inside the handler), output as a service (`--json` versus human rendering chosen by the caller), structured errors carrying a suggestion field, and the 3-tier pyramid (handler unit / in-process sandbox integration / subprocess eval). **Justified divergence:** auto-JSON-when-piped is not adopted — an installer's stdout is read by humans far more often than by programs, and a silent format flip on redirect would make install transcripts unreproducible; `--json` stays explicit.
- **Reference:** `audits/doc-read.sh` — the in-repo precedent for a runtime-neutral command path no agent runtime may be required for. §2's installed command surface mirrors that constraint and reuses its eval idiom.

## Sections (implementation slices)

### §1 — The package is the product boundary

Publishing needs one artifact that carries everything it names. The engine's corpus (`dispatch/`, `audits/`, `docs/`) already sits at paths the code resolves relative to `model.root`, so the cheapest correct move is to make the repository root the package root and let an explicit `files` allowlist define what ships — rather than relocating ~130 enforced path references to satisfy a packager. The allowlist becomes the reviewable, testable statement of what is product and what is Kishore's laptop.

**Implementation default:** package name `@indykish/orly` (scoped, matching the existing `@indykish/oracle` precedent), version seeded at `0.4.0`, `bin.orly` → `bin/orly`.

- **Dimension 1.1** — the published payload contains the engine and excludes every personal file → Test `test_pack_allowlist_excludes_personal_files`
- **Dimension 1.2** — the packaged tarball, extracted to a scratch directory, runs `orly validate` successfully with no dotfiles checkout present → Test `test_packed_tarball_validates_standalone`
- **Dimension 1.3** — the root manifest version is the single source of truth; `orly --version` reports it → Test `test_version_reported_from_manifest`

### §2 — `orly init` and `orly update` materialise the harness into a repository

The registry has always declared where each pack's files should land; nothing ever moved them. This slice implements that consumer. In a target repository `init` renders `AGENTS.md` from the chosen profile, copies every selected pack's `managed_files` to its declared target, installs the git hooks and sets `core.hooksPath`, and writes `.oracle/ruleset.lock` recording the engine version, selected packs, and a content hash and mode per materialised file. `update` re-runs materialisation against a newer engine version, so a rule change costs one command per repository. Both are idempotent; `doctor` compares the lock against disk so drift is detected rather than silent — the condition cache-kit has been in for four weeks.

**Implementation default:** materialise into the repository rather than resolving from the installed package at runtime, because vendored files need no JavaScript toolchain in a Rust or Zig repository, no `PATH`, and no network inside a hook — a `git clone` in a fleet container carries the complete rule set. The accepted cost is M01's zero-sync-commit property; `update` plus lock-drift reporting is what replaces it.

- **Dimension 2.1** — `init` in a fresh repository produces `AGENTS.md`, the pack files at their declared targets, hooks, and the lock → Test `test_init_materialises_fresh_repository`
- **Dimension 2.2** — a second `init` over the first produces a byte-identical tree → Test `test_init_is_idempotent`
- **Dimension 2.3** — only the selected profile's packs are materialised, and no file is written whose own citations are absent → Test `test_init_materialises_coherent_pack_closure`
- **Dimension 2.4** — `init` sets `core.hooksPath` and the installed hooks keep the `GIT_DIR`-unsetting preamble → Test `test_init_installs_scoped_hooks`
- **Dimension 2.5** — `doctor` reports drift when a materialised file is edited, and is silent when it is not → Test `test_doctor_detects_materialised_drift`
- **Dimension 2.6** — `update` moves a repository from an older pinned version to the current one and reports what changed → Test `test_update_repins_and_reports`
- **Dimension 2.7** — `--json` emits the structured result; the human path emits none of it → Test `test_install_json_contract`
- **Dimension 2.8** — the accepted-and-ignored `--global` flag is rejected as unknown, with a message naming the replacement, and no tracked file still references it (RULE NDC; no compatibility alias) → Test `test_global_flag_rejected_and_unreferenced`

### §3 — Persona and product become opt-in packs

A stranger must not inherit Kishore's address tags, banned-vocabulary list, judgment notes, or agentsfleet's vault names and file paths — the leak is already observable, since cache-kit's generated `AGENTS.md` tells a Rust crate its project name is `agentsfleet`. Core documents become pack-gated the same way section content already is, `SOUL.md`'s body is fenced into a new `persona.indy` pack, the persona-bearing sections of the operating model are fenced alongside it, and a `kernel` profile selects neither persona nor product. `msid-ui.sh` moves out of `universal.authoring` into the surfaces that own it, so no Rust crate receives a UI gate again. The 38-byte headroom problem dissolves as a side effect: the kernel render is materially smaller than the full one.

- **Dimension 3.1** — the `kernel` profile's render contains no persona token and no product token → Test `test_kernel_render_excludes_persona_and_product`
- **Dimension 3.2** — the `global` render is byte-identical to today's `AGENTS.md` apart from §4's path changes → Test `test_global_render_unchanged_by_pack_split`
- **Dimension 3.3** — a profile selecting `persona.indy` renders the fenced body in full → Test `test_persona_pack_renders_when_selected`
- **Dimension 3.4** — the rendered kernel is under the size cap with margin → Test `test_kernel_render_within_size_cap`
- **Dimension 3.5** — a Rust-only profile receives no UI or Zig gate → Test `test_rust_profile_excludes_foreign_gates`

### §4 — Rule citations resolve inside the consuming repository

Every rule citation currently names an absolute path under one home directory, and an audit asserts that anchor as an invariant — so removing the folder tie means inverting the check that exists to preserve it. Citations become repository-relative, resolving identically for Kishore, a colleague, a CI runner, and a fleet container. The audit inverts to assert the new property and stops reading the developer's live agent settings, so the same repository contents grade the same way on every machine.

- **Dimension 4.1** — no rendered profile cites an absolute home-directory path → Test `test_no_render_cites_absolute_home_path`
- **Dimension 4.2** — every path a render cites resolves inside the consuming repository after `init` → Test `test_reference_closure_resolves_repo_relative`
- **Dimension 4.3** — the audit grades identically with an absent or unrelated `$HOME` → Test `test_audit_independent_of_live_agent_settings`
- **Dimension 4.4** — the blast-radius grep for the old anchor returns zero hits in rendered and rule surfaces → Test `test_anchor_sweep_clean`

### §5 — A release gate, and an install story that matches reality

This repository now publishes an artifact other repositories depend on, and its tests currently run only on one laptop behind a hand-set `core.hooksPath`. One workflow runs the audit chain and the packaging boundary check on pull requests, so what ships has been proven somewhere other than the author's machine. Consumer repositories receive nothing here: their governance step is one line in their existing CI, decided at adoption. Alongside it the README's ten steps collapse to one command, with the personal-machine concerns (dotfile copies, skills overlay, vault provisioning) separated into an optional section a colleague can skip, and the architecture document records the inversion and names what it supersedes.

- **Dimension 5.1** — the workflow runs the audit chain, fails on a seeded governance violation, and references no absolute developer path → Test `test_ci_gates_release_without_developer_paths`
- **Dimension 5.2** — the README's harness install is a single command block, with machine setup in its own optional section → Test `test_readme_harness_install_is_one_command`
- **Dimension 5.3** — the architecture document describes the repository-scoped model and names the superseded thin model → Test `test_architecture_doc_records_supersession`

## Interfaces

```
orly init [--profile <NAME>] [--json] [--force] [--no-hooks]
orly update [--json] [--force]

  Materialises into the current git repository:
    AGENTS.md              rendered from <NAME> (default: inferred from repositories.json, else "kernel")
    <pack target>...       every selected pack's managed_files, per registry source -> target
    .githooks/*            hooks; core.hooksPath set unless --no-hooks
    .oracle/ruleset.lock   {schema_version, orly_version, profile, packs[], files{path:{sha256,mode}}}

  --force   overwrite files whose hash does not match the lock (default: refuse and report)
  --json    emit {"ok":bool,"profile":str,"packs":[],"written":[],"skipped":[],"errors":[{"path","message","suggestion"}]}

  Exit: 0 success · 1 refused or failed (errors populated) · 2 usage

orly doctor
  Adds: lock currency (every recorded hash and mode matches disk), hooksPath installation,
  and pinned-versus-installed engine version.
  Exit: 0 clean · 1 drift or missing installation, one line per finding.
```

## Failure Modes

| Mode | Cause | Handling (system response + what the caller observes) |
|------|-------|--------------------------------------------------------|
| Not a repository | `init` run outside a git work tree | Refuse before any write; message names the directory and suggests `git init`; exit 1 |
| Foreign `AGENTS.md` | Target already has a hand-written `AGENTS.md` | Refuse without `--force`; message names the file and states that `--force` overwrites; exit 1 |
| Hooks already claimed | `core.hooksPath` set to a path `init` did not install | Refuse to retarget; report the existing value and suggest `--no-hooks`; exit 1 |
| Materialised drift | A managed file edited in place, hash mismatched | `init`/`update` refuse that file without `--force`; `doctor` reports it; exit 1 |
| Incoherent or missing pack source | A selected pack's file cites a façade no selected pack provides, or a registry `managed_files` source is absent from the package | Refuse the whole install atomically — no partial tree; name the pack, the citing file, and the missing target; exit 1 |
| Unknown profile | `--profile` names a profile the package does not carry | Refuse; list the available profile names; exit 2 |
| Partial write interrupted | Process dies mid-materialisation | Stage into a temporary directory and move into place only after every file is written; an interrupted run leaves the tree untouched |
| Dirty target tree | `init` would overwrite uncommitted work | Report the dirty paths it would touch and refuse without `--force`; exit 1 |
| Stale pin | Repository pinned to an engine version older than the installed one | `doctor` reports both versions and names `orly update`; exit 1 |

## Invariants

1. The published payload carries no personal file — enforced by the `files` allowlist plus a packaging test asserting the extracted tarball's top-level set (Dimension 1.1).
2. No rendered profile cites an absolute home-directory path — enforced by a grep check in `audits/rule-paths.sh` over every profile render, run in `make audit` (Dimension 4.1).
3. Every path a render cites resolves inside the consuming repository — enforced by `referenceClosureErrors` re-rooted at the target, which already throws on a missing reference (Dimension 4.2).
4. Materialised content matches its recorded hash and mode — enforced by `orly doctor` comparing the lock against disk, run in the installed pre-push hook (Dimension 2.5).
5. `init` is atomic and idempotent — enforced by staging to a temporary directory before the move, plus a byte-identical-tree test over two consecutive runs (Dimension 2.2, "Partial write interrupted").
6. The audit's verdict depends only on repository contents — enforced by removing the live `$HOME` agent-settings read and by a test that grades identically under a scratch `$HOME` (Dimension 4.3).
7. A materialised pack set is self-contained and self-excluding — every façade cited by a materialised file is itself materialised (closure check refuses the install, Dimension 2.3), and installed dispatchers never glob their own materialised copies (RULE GLS's existing self-exclusion idiom, asserted by an eval case over a materialised tree).

## Metrics & Observability

| Metric / event | Owner | Fires when | Properties allowed | Privacy guard | Test proof |
|----------------|-------|------------|--------------------|---------------|------------|
| not applicable — no product/operator signal changes | not applicable | internal developer tooling; `init` emits no telemetry by design, and adding any would ship a network call inside a hook path | none | no data leaves the machine | `test_install_makes_no_network_call` |

**Metrics review:** no analytics/funnel playbook update required — the harness has no product surface and deliberately acquires no telemetry; a developer tool that phones home from a git hook is a trust cost with no offsetting signal.

## Test Specification (tiered)

| Dimension | Tier | Test | Asserts (concrete inputs → expected output) |
|-----------|------|------|---------------------------------------------|
| 1.1 | unit | `test_pack_allowlist_excludes_personal_files` | The packaged file list contains `bin/orly` and `dispatch/`, and contains no `.zshrc`, `.claude/`, `Library/`, or `.codex/` entry |
| 1.2 | e2e | `test_packed_tarball_validates_standalone` | Tarball extracted to a scratch directory, invoked with a scratch `$HOME`: `validate` exits 0 |
| 1.3 | unit | `test_version_reported_from_manifest` | `--version` prints exactly the root manifest's version string |
| 2.1 | integration | `test_init_materialises_fresh_repository` | Empty initialised repository → `AGENTS.md`, pack targets, hooks, and lock all exist; lock lists every written path with a mode |
| 2.2 | integration | `test_init_is_idempotent` | Two consecutive runs → identical recursive listing and hashes; second run reports zero written |
| 2.3 | integration | `test_init_materialises_coherent_pack_closure` | A Rust-only profile writes `write_rust.md`, writes no `write_zig.md`, and refuses a pack whose file cites an unmaterialised façade |
| 2.4 | integration | `test_init_installs_scoped_hooks` | `core.hooksPath` equals the installed directory; each hook's first lines unset `GIT_DIR` and the four sibling variables |
| 2.5 | integration | `test_doctor_detects_materialised_drift` | Appending a byte to a managed file → `doctor` exits 1 naming that path; reverting → exits 0; changing its mode is also caught |
| 2.6 | integration | `test_update_repins_and_reports` | A repository pinned to an older version → `update` rewrites changed files, repins the lock, and lists exactly what changed |
| 2.7 | unit | `test_install_json_contract` | `--json` parses as an object carrying `ok`, `profile`, `packs`, `written`, `skipped`, `errors`; the human path emits no JSON |
| 2.8 | unit | `test_global_flag_rejected_and_unreferenced` | `sync --global` exits non-zero naming `sync`; a tracked-file grep for the flag returns zero hits |
| 3.1 | unit | `test_kernel_render_excludes_persona_and_product` | The `kernel` render contains zero occurrences of the persona handles, the banned-vocabulary list, the vault names, and the product name |
| 3.2 | unit | `test_global_render_unchanged_by_pack_split` | The `global` render differs from the committed baseline only in lines the anchor re-point touches |
| 3.3 | unit | `test_persona_pack_renders_when_selected` | A profile selecting `persona.indy` renders the fenced body in full |
| 3.4 | unit | `test_kernel_render_within_size_cap` | The `kernel` render is below the size cap by a margin large enough to absorb one added rule |
| 3.5 | unit | `test_rust_profile_excludes_foreign_gates` | The `cache-kit` profile's managed set contains no `msid-ui.sh` and no Zig or TypeScript façade |
| 4.1 | unit | `test_no_render_cites_absolute_home_path` | No profile's render matches an absolute home-directory path pattern |
| 4.2 | integration | `test_reference_closure_resolves_repo_relative` | After `init` in a sandbox, every path the rendered `AGENTS.md` cites exists relative to that sandbox |
| 4.3 | integration | `test_audit_independent_of_live_agent_settings` | `audits/rule-paths.sh` grades identically with `$HOME` pointed at an empty scratch directory |
| 4.4 | unit | `test_anchor_sweep_clean` | Word-boundary grep for the old anchor over rendered and rule surfaces returns zero hits |
| 5.1 | e2e | `test_ci_gates_release_without_developer_paths` | The workflow's audit step exits non-zero on a tree carrying a stale render, and a grep of the workflow for an absolute home path returns zero hits |
| 5.2 | unit | `test_readme_harness_install_is_one_command` | The README harness-install section carries exactly one fenced command block |
| 5.3 | unit | `test_architecture_doc_records_supersession` | The architecture document names the lock, the materialisation, and the superseded thin model |
| — | integration | `test_install_makes_no_network_call` | `init` completes with outbound network denied |
| — | regression | `test_existing_gate_criteria_unchanged` | Every M01 gate criterion evaluates as before on this repository |
| — | regression | `test_doc_read_ledger_still_green` | `evals/ledger/run.sh` passes unchanged after the command-path move |

## Acceptance Rubric (single scoring surface)

| # | Criterion (observable outcome) | Verify (copy-paste) | Expected | Priority | Graded (VERIFY) |
|---|--------------------------------|---------------------|----------|----------|-----------------|
| R1 | A fresh repository installs in one command with no dotfiles checkout (§1, §2) | `bash evals/install/run.sh` | `0 failed` | P0 | |
| R2 | The published payload carries no personal file (§1) | `npm pack --dry-run --json \| grep -cE '"path": *"(\.zshrc\|\.claude/\|Library/)'` | `0` | P0 | |
| R3 | No render cites an absolute home path (§4) | `bin/orly render --profile kernel \| grep -c '/Users/'` | `0` | P0 | |
| R4 | The kernel render excludes persona and product (§3) | `bin/orly render --profile kernel \| grep -ciE 'agentsfleet\|ZMB_'` | `0` | P0 | |
| R5 | Drift and stale pins are detected (§2) | `bash evals/install/run.sh drift` | `0 failed` | P0 | |
| R6 | The audit grades identically under a scratch `$HOME` (§4) | `HOME=$(mktemp -d) bash audits/rule-paths.sh` | exit 0 | P0 | |
| R7 | Diff stays inside Files Changed | `git diff --name-only master...HEAD` | 0 paths missing from the Files Changed table | P0 | |
| S1 | Unit tests pass | `cd orly && bun test src` | exit 0 | P0 | |
| S2 | Full audit chain clean | `make audit` | `ALL CHECKS PASSED` | P0 | |
| S3 | Cross-agent rule comprehension holds after the pack split | `make llmevals` | threshold met across all four agents | P0 | |
| S7 | No secrets | `gitleaks detect` | exit 0 | P0 | |
| S8 | No oversize source file | `git diff --name-only master...HEAD \| grep -v '\.md$' \| xargs wc -l 2>/dev/null \| awk '$1>350 && $2!="total"'` | no output | P0 | |
| S9 | Orphan sweep | Dead Code Sweep greps below | 0 matches | P0 | |

**Grading protocol (VERIFY):** run the Verify command verbatim; grade ONLY from its output. Graded = ✅/❌ + the one decisive output line (`342 passed`); long evidence goes to PR Session Notes with a pointer here. **Ship gate:** every row graded, every P0 ✅ → eligible for CHORE(close); any ❌ or empty cell → return to EXECUTE; a P1 ❌ ships only with an Indy-acked deferral quote in Discovery.

## Dead Code Sweep

**1. Orphaned files — deleted from disk and git.**

| File to delete | Verify |
|----------------|--------|
| none — this milestone adds and re-points; the agentsfleet-only leaf audits leave with their pack when that repository adopts, not here | `true` |

**2. Orphaned references — zero remaining imports/uses.**

| Deleted symbol/import | Grep | Expected |
|-----------------------|------|----------|
| `--global` | `git grep -n -w -- '--global' \| grep -v '\.git/'` | 0 matches |
| the absolute rule-path anchor | `git grep -n -F '~/Projects/dotfiles/dispatch'` | 0 matches |
| `requireGlobalOnly` | `git grep -n -w 'requireGlobalOnly'` | 0 matches |

## Out of Scope

- **agentsfleet adoption** — its own workstream (M03_002) and its own Pull Request there; this spec ships the installer, not the adoption. Its governance CI step is decided at that time, as one line in an existing workflow.
- **cache-kit adoption** — M03_003, which also completes M01's deferred Dimension 6.2 by replacing the frozen `.oracle/` snapshot rather than deleting it.
- **Mechanising the remaining rule corpus** — the ledger reports 26 of 278 clauses classified; converting more prose to checks pays only once installation works.
- **Removing the personal-machine layer** — `bin/link-bin-dotfiles`, `update-skills`, and the 1Password provisioning stay as they are; §5 only separates them in the README so a colleague can skip them.

---

## Product Clarity (authoring record)

1. **Successful user moment** — A colleague clones a repository they have never seen, runs one command, and their coding agent immediately refuses to commit a file that violates a rule nobody explained to them. No walkthrough happened.
2. **Preserved user behaviour** — Kishore's flow is untouched: the same rendered content reaches the same four agent homes, `orly gate` evaluates the same criteria, and existing specs, hooks, and audits keep working. The one property deliberately given up is M01's zero-consumer-sync-commit guarantee, replaced by `orly update`.
3. **Optimal-way check** — The unconstrained-optimal shape is a hosted rule service with signed bundles. The gap is deliberate: a package plus materialised files needs no service to operate, no availability budget, and no network inside a hook. The remaining distance is update ergonomics, which the lock makes explicit rather than magical.
4. **Rebuild-vs-iterate** — Iterate. The gates engine, render pipeline, eval harness, and the `managed_files` data model are sound; what is missing is the consumer of a model that already exists. A rebuild would trade away run-to-run determinism the evals currently prove, which is wrong by default.
5. **What we build** — A root package manifest with an explicit payload allowlist; `init`, `update`, and the lock; a persona pack, a kernel profile, and a gate-ownership correction; repository-relative citations with the inverted audit; one release workflow; the sandbox evals that prove all of it.
6. **What we do NOT build** — A rule server (availability cost, no offsetting benefit); a plugin API for third-party packs (no second author yet); per-agent adapters (the whole point is that reading a file and running a command are all any agent needs); telemetry (trust cost inside a hook path); an auto-updater (the lock reports staleness; the human decides); governance workflows in consumer repositories (they own their CI).
7. **Fit with existing features** — Compounds with the M01 gates engine, which becomes runnable anywhere, and the M02 ledger, whose scoreboard becomes a per-repository artifact. The one thing it must not destabilise is `make audit` here: the audit is the harness's own proof, and a milestone that loosens it to ship itself has failed.
8. **Surface order** — CLI-first, the repository default. There is no other surface.
9. **Dashboard restraint** — No coverage percentage or "rules enforced" score is surfaced by `init`. The ledger reports 26 of 278 clauses classified; publishing a headline number before the corpus is triaged would be a quality claim ahead of its counter.
10. **Confused-user next step** — Every refusal names the offending path and the exact command that resolves it, and `orly doctor` is the single "what is wrong here" entry point. If a user must ask Kishore, a message is missing from item 5.

## Decomposition & alternatives (patch vs refactor)

- **Chosen shape:** Five slices ordered so each is independently verifiable: packaging boundary (§1) before the installer that ships through it (§2); the pack split (§3) before the path inversion (§4), because a stranger's render must exist before it can be checked for portability; the release gate and documentation truth-up (§5) last, once there is a packaged engine to gate and a final surface to describe; the dead-flag removal rides in §2 with the rest of the command surface.
- **Alternatives considered:** (a) *Keep M01's thin model and fix the install script* — rejected: the symlink-plus-`ORLY_ROOT` mechanism cannot reach a machine without the checkout, which is the entire failure being addressed; no amount of scripting makes a fixed absolute path portable. (b) *Resolve rule documents from the installed package at runtime instead of materialising* — rejected: it requires a JavaScript toolchain and a resolvable `node_modules` inside Rust and Zig repositories and inside every fleet container, reintroducing an install-order dependency in the class of failure this milestone removes. (c) *Relocate the corpus under `orly/` and publish that subdirectory* — rejected: it moves ~130 enforced path references for no behavioural gain; an allowlist states the same boundary without the churn. (d) *Split the engine into its own repository first* — rejected as sequencing, not direction: the split is mechanical once the payload boundary and the path inversion exist, and doing it first would re-point every citation twice.
- **Patch-vs-refactor verdict:** this is a **refactor** because the defect is architectural — the unit of installation is the machine, and every symptom (hand-set hooks, absolute citations, a runtime-coupled gate, a `$HOME`-reading audit, a four-week-frozen consumer) descends from that one choice. Patching any single symptom leaves the others. The refactor is bounded: it changes where files land and how paths resolve, and changes no gate semantics, which is why the existing eval suite is the regression net. It knowingly supersedes M01_001 §4; that decision is recorded in Discovery rather than left for a reader to infer.

## Discovery (consult log)

- **Consults** — Architecture / Legacy-Design / gate-flag triage: the question asked + Indy's decision.
  - Aug 16, 2026 — Propagation model. Asked whether restoring materialisation should proceed given M01_001 §4 chose thin distribution for "zero consumer sync commits". Indy asked what M01's proposal had been; on the answer, directed the work forward. Decision: materialise per repository, pinned and updatable; M01's zero-sync property is knowingly traded for portability.
  - Aug 16, 2026 — CI scope. Proposed a governance workflow in every repository. Indy challenged the need. Decision: one workflow in this repository only, justified as the release gate for the published package; consumer repositories add one line to their existing CI at adoption.
  - Aug 16, 2026 — Distribution channel. Decision: publish to npm as `@indykish/orly`.
- **Metrics review** — events added, extra events found during `/review`, analytics/funnel playbook update or the explicit no-change reason.
- **Skill-chain outcomes** — `/write-unit-test`, `/review`, `kishore-babysit-prs` results (order per `AGENTS.md` CHORE(close); iteration counts, findings dispositioned).
- **Deferrals** — every "deferred to follow-up" needs an **Indy-acked verbatim quote** here, format `> Indy (YYYY-MM-DD HH:MM): "<quote>" — context: <which item, why>`.
