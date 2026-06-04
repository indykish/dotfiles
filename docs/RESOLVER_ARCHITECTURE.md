# Resolver Architecture — operating-model proposal

Date: Jun 04, 2026
Status: PROPOSAL — awaiting Indy approval before execution
Owner: Orly (Oracle)
Scope: `~/Projects/dotfiles` operating model + cross-repo rule-doc references

> Design doc, not a milestone spec (dotfiles has no `docs/v*/` train). Uses the
> spec's intent → topology → verification → evals spine. Lands on `master`.

---

## 1 · Intent (the testable goal)

**Goal (as a test name):** *"Writing a `*.zig` file presents ONE latent façade
(`resolvers/write_zig.md`) the agent reads and ONE deterministic façade
(`resolvers/write_zig.sh`) the machine runs; every rule is tagged DETERMINISTIC
(has a `.sh` check + fixtures) or JUDGMENT (has an LLM-judge eval); the two
façades cannot drift because an audit ties tags ↔ checks ↔ evals."*

**Why:** Today the Zig discipline is scattered: `docs/ZIG_RULES.md` (40 prose
sections), `docs/gates/*.md` (20 cards restating values), 10 `scripts/audit-*.sh`
checks. Nothing makes "did I adhere to all Zig rules?" a runnable, testable
question. This unifies them into a **façade pair per language** and adds **evals
in both spaces** so adherence is proven, not promised.

## 2 · Core insight — a resolver is a FAÇADE PAIR over one gate set

A resolver is not one file. It is the dispatcher *concept*, presenting two faces:

```
          ┌──────────── THE ZIG RESOLVER (one concept) ────────────┐
LATENT ──▶ │  resolvers/write_zig.md   façade for the AGENT          │
SPACE      │     prose dispatcher: "writing zig? adhere to this."    │
           │     every § tagged [DETERMINISTIC → sh::X] or [JUDGMENT]│
           │            │ DETERMINISTIC tags link to ↓               │
DETERM. ──▶│  resolvers/write_zig.sh   façade for the MACHINE        │
SPACE      │     runs the checkable subset → pass/fail + 🟡 nudges   │
           │            │ calls ↓                                    │
           │  scripts/audit-*.sh  +  inline checks (the leaf checks) │
           └─────────────────────────────────────────────────────────┘
```

- **`write_zig.md`** = `docs/ZIG_RULES.md` renamed+moved. It was always the
  latent dispatcher, misfiled as passive `docs/` reading. No content rewrite —
  it gains per-section enforcement tags.
- **`write_zig.sh`** = the deterministic façade (the runnable subset).
- **`write_ts_adhere_bun.md` / `.sh`** = the TS/Bun pair (from `BUN_RULES.md`).

**`gates/*.md` is DISSOLVED** (Model A) via **merge-then-delete, not delete**:
for each card, extract the *delta* (prose not already in the latent façade),
merge it into `write_zig.md` **with an enforcement tag** — strengthening
latent-space determinism — and only then delete the card. Mechanical content →
the `.sh`. Nothing unique dies; the façade gets *richer* (e.g. pub-surface's
"articulate in one sentence why it's operations-over-value" tie-break becomes a
tagged `[JUDGMENT]` section). No middle layer, no manifest, no drift — the `.sh`
is the executable truth, the `.md` is the prose truth, the tag bridges them.

## 3 · Enforcement tags (how every section becomes deterministic-or-honest)

Each section of the latent façade carries one tag:

| Tag | Meaning | Enforced by | Eval kind |
|---|---|---|---|
| `[DETERMINISTIC → write_zig.sh::<check>]` | machine can pass/fail it | the `.sh` check `<check>` | fixture (pass+fail) |
| `[JUDGMENT]` | no script can decide; agent decides at write time | agent reading the prose | LLM-judge scenario |

This answers "make the other sections deterministic": you walk all 40 sections,
tag each. A DETERMINISTIC tag with no `.sh` check is a *build-the-check* TODO; a
section that genuinely can't be checked is honestly labelled JUDGMENT. No section
escapes classification.

## 3.1 · Signal semantics (🟢 / 🔴 / 🟡) — how an agent interprets output

Three signals, three distinct meanings. 🟡 is the subtle one: it is **not** a
failure — it is an open question the determinism boundary cannot answer.

| Signal | Meaning | Agent MUST | Exit |
|---|---|---|---|
| 🟢 GREEN | deterministic check passed | proceed | 0 |
| 🔴 RED | deterministic check failed | STOP, fix code, re-run | 1 (blocks) |
| 🟡 YELLOW | judgment-only rule; no script can decide | read linked §, make the call, **state the verdict in chat** | 0 (does NOT block script) |

**🟡 is an open question, not a verdict.** Red = "you're wrong." Yellow = "I can't
check this; *you* decide and say so." Misreading yellow as ignorable (it isn't) or
as fixable-blindly (it isn't) are both bugs.

**Yellow blocks the TURN, not the script.** Exit code is 0, but HARNESS VERIFY
flags any 🟡 with no stated verdict as an incomplete turn. Required response shape:
```
🟡 JUDGMENT — TGU (Tagged-Union over optional-field structs): result w/ failure modes?
  → agent emits one of:
     "TGU: applied — union(enum) with payload at foo.zig:42"
     "TGU: N/A — single return value, no failure modes"
```
Silence on a 🟡 = incomplete turn. This is how judgment stays mandatory without
faking a machine check.

## 4 · Two worked gates (the concrete shape)

**GATE 1 — LENGTH (deterministic):**
```
write_zig.md §Length:
  - `.zig` ≤ 300 lines; split by concern when over.
    [DETERMINISTIC → write_zig.sh::length]  (how: §Module Split Pattern)
write_zig.sh:  resolver_length_gate 300
run:  LENGTH 🔴 foo.zig: 340 (cap 300) — split (see write_zig.md §Module Split)
→ machine decides. pass/fail.
```

**GATE 2 — TAGGED-UNIONS (latent / judgment, no script):**
```
write_zig.md §Tagged unions for result types:
  - Result with distinct failure modes → union(enum) w/ payload, not
    optional-field struct. Callers need the *reason*, not the verdict.
    [JUDGMENT]
write_zig.sh:  resolver_judgment "TGU" "result w/ failure modes? union(enum)…"
run:  TGU 🟡 JUDGMENT — result w/ failure modes? union(enum), not optional-field
→ agent decides. un-passable nudge; the .md carries the WHY.
```

## 5 · Resolver set + coverage

| Latent façade (.md) | Deterministic façade (.sh) | Triggers |
|---|---|---|
| `write_zig.md` | `write_zig.sh` | `*.zig` |
| `write_ts_adhere_bun.md` | `write_ts_adhere_bun.sh` | `*.ts *.tsx *.js *.jsx` |
| `write_sql.md` | `write_sql.sh` | `schema/*.sql` |
| `write_docs.md` | `write_docs.sh` | `AGENTS.md`, specs |
| `write_any.md` | `write_any.sh` | any source (length-350, logging, msid, nlr/nlg, greptile-nudge) |

20-gate disposition: 11 mechanical → dissolve to `.sh`; 6 judgment → merge prose
to façade `.md`, `.sh` prints 🟡; 1 (verification) = HARNESS VERIFY plane, stays
AGENTS.md prose; umbrella (zig) = the resolver itself.

## 6 · EVALS — both spaces (the loop-closer)

A resolver you can't test is a hope. Two eval kinds, one coherence audit.

### 6.1 Deterministic façade evals — fixtures
```
scripts/resolver-evals/fixtures/
  length_300_pass.zig    → write_zig.sh expects exit 0
  length_301_fail.zig    → expects exit 1
  ufs_dup_string.zig     → expects exit 1
  deinit_missing.zig     → expects exit 1
scripts/resolver-evals/run.sh  → runs each fixture, diffs actual vs expected exit
```
Every `[DETERMINISTIC → sh::X]` rule MUST have ≥1 pass + ≥1 fail fixture.

### 6.2 Latent façade evals — LLM-judge (extend existing `scripts/llmevals/`)
```
scripts/llmevals/write_zig_adherence.yaml
  - scenario: "write a Zig fn returning a result with 2 failure modes"
    assert_judge: "uses union(enum) with payloads, not optional-field struct"
    rule: TGU [JUDGMENT]
```
Every `[JUDGMENT]` rule MUST have ≥1 LLM-judge scenario.

### 6.3 Coherence audit — `scripts/audit-resolver-coverage.sh`
Ties the three together; fails if any of:
- a `[DETERMINISTIC → sh::X]` tag has no check `X` in the `.sh`
- a DETERMINISTIC rule has no pass+fail fixture
- a `[JUDGMENT]` rule has no LLM-judge scenario
- a `.sh` check exists with no tag in the `.md` (orphan check)

This replaces the rejected manifest's only real job — completeness — by reading
the façades directly, not a parallel data file.

## 6.4 · Rule-code glosses (self-explaining output)

Cryptic codes (`UFS`, `FLL`, `NLR`, `TGU`, `PRI`, `NDC`, `NLG`, `ORP`,
`TST-NAM`) are write-only — the author knows them; the next reader greps blind.
Per the AGENTS.md acronym rule, each gets a **short gloss on first sight** (not
the full link). The gloss is canonical in **one place** (`RULES.md` legend) and
**baked into resolver output** so a human watching a commit reads meaning, not
codes.

| Code | Gloss (printed inline) |
|---|---|
| `NDC` | No Dead Code |
| `NLR` | No Legacy Retained (touch-it-fix-it) |
| `NLG` | No Legacy compat shims (pre-v2.0.0) |
| `UFS` | Unified Form for Symbols (literals → named consts) |
| `TGU` | Tagged-Union over optional-field structs |
| `PRI` | Prompt-injection Resistance from user Input |
| `ORP` | ORPhan sweep (cross-layer on rename/delete) |
| `FLL` | File & Function Length Limits |
| `TST-NAM` | TeST NAMing (milestone-free) |

**Mechanism:**
- `RULES.md` gains a one-line legend per rule heading so any reader expands it once.
- `lib.sh` carries the gloss map; `resolver_run_helper` / `resolver_judgment`
  print `CODE (Gloss)` in every row. Example:
  `UFS 🟢 pass — Unified Form for Symbols (literals → named consts)`.
- `audit-resolver-coverage.sh` fails if a code appears in a `.sh` row with no
  gloss-map entry (no naked codes in output).

## 7 · Three-plane firing

| Plane | When | Invocation |
|---|---|---|
| Latent | EXECUTE, about to write | agent reads `write_zig.md`; runs `write_zig.sh <file>` as early warning |
| Anchor | HARNESS VERIFY (end-of-turn) | `write_zig.sh --staged`; 🔴 → back to EXECUTE |
| Backstop | COMMIT | `.git/hooks/pre-commit` runs all `resolvers/*.sh --staged` |
| CI | eval gate | `scripts/resolver-evals/run.sh` + coherence audit |

## 8 · Applicable gates this change trips

- **Invariance Suite Gate** (no override) — AGENTS.md edits. Needs:
  AGENTS_INVARIANCE.md question, DOTFILES_RESIDENT path(s) for `resolvers/`,
  `make audit` ALL CHECKS PASSED, signoff before push.
- **DOC READ / LENGTH** — façade + resolver edits.

## 9 · Failure modes → mitigations

| Failure | Mitigation |
|---|---|
| `.md` tag drifts from `.sh` check | coherence audit fails CI |
| Cross-repo (`usezombie`) ref to `docs/ZIG_RULES.md` breaks | §11 cross-repo audit; rewrite refs in the same change OR leave a stub redirect |
| pre-commit latency | resolvers exit instantly on no-match `--staged` |
| Judgment rule silently ignored | 🟡 row every run + LLM-judge eval catches non-adherence |
| Façade rename loses git history | `git mv` preserves blame |

## 10 · Invariants (code-enforced)

1. One verdict format — all `.sh` source `lib.sh`.
2. No façade drift — coherence audit.
3. Determinism — length cap intrinsic to file content, never git history.
4. Every rule classified — no untagged section (audit enforces).
5. Every rule evaluable — DETERMINISTIC→fixture, JUDGMENT→judge (audit enforces).
6. No naked codes — every rule code in output carries its gloss (audit enforces).

## 11 · Cross-repo blast radius (must resolve before execution)

`docs/ZIG_RULES.md` / `BUN_RULES.md` are referenced by the `usezombie` product
repo (`AGENTS.md` line 66, `EXECUTE_DOC_READS.md`, possibly Makefile/CI). Renaming
in dotfiles without updating usezombie breaks those refs. Options to decide at
execution: (a) rewrite usezombie refs in a paired PR; (b) keep a `docs/ZIG_RULES.md`
one-line stub pointing at the new path. **Decision deferred to execution start;
flagged here so it is not a surprise.**

## 12 · Discovery (consult log)

- **Façade-pair insight (Indy, Jun 04):** *"the current ZIG_RULES.md is actually
  a resolvers/ZIG.md … write_zig.sh is the deterministic space facade, write_zig.md
  is from latent space facade."* → resolver = `.md`+`.sh` pair, not one file.
- **Manifest rejected:** resolver `.sh` is executable truth; manifest duplicates.
- **gates/*.md dissolved (Model A):** middle layer restating mechanical values
  (drift) or duplicating textbook prose. Mechanical→`.sh`, teaching→façade `.md`.
- **new=300/edited=350 rejected:** git-state-dependent → flat-300 zig/ts intrinsic.
- **Evals added (Indy, Jun 04):** *"have evals for the resolvers both in latent
  and deterministic space."* → fixtures + LLM-judge + coherence audit.
- **Glosses added (Indy, Jun 04):** *"UFS, FLL are a bit cryptic … expand a bit
  so the human or agent knows what it is, i dont need the full link."* → gloss
  map in RULES.md legend + baked into resolver output (§6.4).

## 13 · Acceptance criteria

- [ ] `resolvers/{lib,write_zig,write_ts_adhere_bun,write_sql,write_docs,write_any}.{sh}` exist
- [ ] `resolvers/write_zig.md`, `write_ts_adhere_bun.md` exist (renamed from docs/), every § tagged
- [ ] `docs/gates/` dissolved; unique prose merged into façade `.md`s
- [ ] `gates/file-length` logic → 300 (zig/ts) / 350 (rest) in resolvers
- [ ] AGENTS.md Resolver Dispatch table (latent .md + determ .sh columns)
- [ ] `.git/hooks/pre-commit` runs `resolvers/*.sh --staged`
- [ ] `scripts/resolver-evals/` fixtures: every DETERMINISTIC rule pass+fail
- [ ] `scripts/llmevals/` scenario: every JUDGMENT rule
- [ ] `scripts/audit-resolver-coverage.sh` clean (tags↔checks↔evals)
- [ ] rule-code glosses: RULES.md legend + `lib.sh` gloss map; no naked codes in output
- [ ] cross-repo refs (§11) resolved
- [ ] `make audit` ALL CHECKS PASSED + invariance signoff
