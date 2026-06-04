# Resolver Architecture — operating-model proposal (v2)

Date: Jun 04, 2026
Status: PROPOSAL v2 — awaiting Indy approval before execution
Owner: Orly (Oracle)
Scope: `~/Projects/dotfiles` operating model + cross-repo rule-doc references

> Design doc, not a milestone spec (dotfiles has no `docs/v*/` train). Lands on
> `master` via `feat/resolver-architecture`. **v2 supersedes v1** after a 7-lens
> adversarial Chief Technology Officer (CTO) review (38 findings confirmed: 19
> P0 / 16 P1 / 3 P2) returned **REWORK** — concept sound, migration plan
> under-scoped ~10×, two determinism claims overstated. v2 keeps the façade-pair
> core and rewrites the migration, the blast-radius accounting, and the claims to
> match what the mechanisms actually deliver. Every change below is grounded in a
> grep of the branch, not the review prose — file:line citations are real.
> **Per-finding disposition (all 38 + resolved/partial status) is tracked in
> [`RESOLVER_REVIEW_DISPOSITION.md`](./RESOLVER_REVIEW_DISPOSITION.md).**

---

## 0 · What changed from v1 (the review's verdict, absorbed)

| v1 claim / gap | v2 correction |
|---|---|
| "the two façades **cannot drift**" (headline invariant) | Downgraded to **"no missing symbol + prose-pinned thresholds."** The coherence audit proves symbol presence, not that a check enforces the prose. Real semantic anchors added (§3, §6.3). |
| §11 = cross-repo footnote | §8 = **primary in-dotfiles blast-radius inventory** (grounded, ~14 files). Cross-repo is downstream of it (§10). |
| Dissolve `docs/gates/` + rename `*_RULES.md` (single act) | **Staged, non-destructive migration** (§9): scaffold → prove equivalence → atomic switchover. `make audit` never goes red mid-flight. Rollback defined. |
| `make audit` "ALL CHECKS PASSED" as an acceptance bullet | The audit/hook/harness **rewrites are first-class deliverables** (§8, §13) and edit the harness → **explicit Indy sign-off required** (Hard-Safety rule). |
| "nothing unique dies" on merge | A **mechanical merge-loss proof** (`audit-merge-coverage.sh`, §6.5). No card deleted until its delta-landed assertion is green. |
| `🟡` = JUDGMENT-open | **Glyph collision fixed** — `HARNESS_VERIFY_OUTPUT.md:19` already uses `🟡` for "violations addressed." v2 introduces **`🔵 DECIDE`** for judgment-open (§3.1). |
| JUDGMENT "mitigated" / "blocks the turn" | Honestly scoped: **proven for DETERMINISTIC, attested-by-honor for JUDGMENT.** A `HARNESS_VERIFY` JUDGMENT row makes the *attestation* auditable (§11). |
| Helper-absent → `⚪`, exit 0 | A DETERMINISTIC helper that is **absent hard-fails RED** (§10) — no silent green no-op. |
| `.git/hooks/pre-commit` backstop | Wired to **`.githooks/pre-commit`** (`core.hooksPath` = `.githooks`, confirmed) — `.git/hooks/` never runs on a fresh clone. |
| Resolvers run in dotfiles; leaf checks "just run" | **Execution-location model defined** (§10): `bin/sync-agents` **symlinks** (confirmed `:160,176`), so the resolver runs in the product repo against a symlink back to dotfiles. `RESOLVER_ROOT` (target repo) is derived from `git rev-parse --show-toplevel`, NOT `BASH_SOURCE` — so a symlinked resolver scopes to the repo it runs in, not dotfiles. |
| fn≤50 / method≤70 sub-cap | **Not silently dropped** — `resolver_length_gate` is file-cap only today (`lib.sh:107`); v2 names the sub-cap as a delegated/[JUDGMENT] decision in §13. |

> **This doc is the TARGET STATE, not current code.** The resolver WIP on this
> branch (`resolvers/lib.sh`, `resolvers/write_zig.sh`) is v1-era: it still emits
> `🟡` for judgment, returns `⚪`/exit 0 on an absent helper, derives
> `RESOLVER_ROOT` from `BASH_SOURCE`, and wires `audit-ufs.sh --all`. Every such
> correction below is *specified here and implemented during the staged
> migration* (§9), not already present. A second adversarial pass (Jun 04, 21
> resolved / 17 partial) confirmed the partials are "doc correct, code pending" —
> tracked as Stage-0 implementation work, not doc defects.

---

## 1 · Intent (the testable goal)

**Goal (as a test name):** *"Writing a `*.zig` file dispatches a SMALL ORDERED
façade set — the language façade (`resolvers/write_zig.md`) plus the one
cross-cutting façade (`resolvers/write_any.md`) — the agent reads, and the
matching deterministic `.sh` set the machine runs; every rule is tagged
DETERMINISTIC (has a `.sh` check + a prose-pinned fixture) or JUDGMENT (has a
Large Language Model (LLM) comprehension probe); the deterministic value lives
once (in the `.sh`) and the prose references it, so a fixture catches prose↔check
divergence; an audit ties tags ↔ checks ↔ evals ↔ merged-prose."*

> Not literally "one façade" — a write triggers its language façade composed with
> `write_any` (§5). Two façades, fixed and ordered, is still the single runnable
> question v1 lacked; the scatter it kills was 20 cards + 478-line prose doc, not
> "more than one file."

**Why:** Today the Zig discipline is scattered: `docs/ZIG_RULES.md` (478 lines),
`docs/gates/*.md` (20 cards), 10 `scripts/audit-*.sh`. Nothing makes "did I
adhere to all Zig rules?" a runnable, testable question. This unifies them into
a **façade pair per language** and proves adherence in both spaces.

**What v2 does NOT claim:** that the `.md` and `.sh` *cannot* diverge in meaning.
A symbol-presence audit cannot prove that. v2's mechanism for semantic coherence
is **single-source thresholds + prose-pinned fixtures** (§3, §6.1), not the tag.

## 2 · Core insight — a resolver is a FAÇADE PAIR over one gate set

A resolver is not one file. It is the dispatcher *concept*, presenting two faces:

```
          ┌──────────── THE ZIG RESOLVER (one concept) ────────────┐
LATENT ──▶ │  resolvers/write_zig.md   façade for the AGENT          │
SPACE      │     prose dispatcher: "writing zig? adhere to this."    │
           │     every § tagged [DETERMINISTIC → CODE] or [JUDGMENT] │
           │            │ DETERMINISTIC tags link to ↓               │
DETERM. ──▶│  resolvers/write_zig.sh   façade for the MACHINE        │
SPACE      │     owns the threshold values; runs the checkable       │
           │     subset → 🟢/🔴 + 🔵 judgment nudges                  │
           │            │ calls ↓                                    │
           │  scripts/audit-*.sh  +  inline checks (the leaf checks) │
           └─────────────────────────────────────────────────────────┘
```

- **`write_zig.md`** = `docs/ZIG_RULES.md` **merged with the Zig-relevant
  `docs/gates/*.md` deltas**, perfected and made more deterministic — not a bare
  rename. It gains per-section enforcement tags; mechanical content moves to the
  `.sh`; teaching prose stays.
- **`write_zig.sh`** = the deterministic façade. **It owns every threshold value
  verbatim** (`resolver_length_gate 350`); the `.md` *references* the value
  ("see `write_zig.sh::length`"), never restates the number. This is the v2
  anti-drift mechanism — one source, not two copies bridged by a tag.

**`gates/*.md` is DISSOLVED selectively, not wholesale** (§5 taxonomy): authoring
gates merge into a façade `.md`; **process/meta gates stay in `AGENTS.md`**. Merge
is **merge-then-delete with a proof gate** (§6.5): a card is deleted only after
`audit-merge-coverage.sh` confirms its non-boilerplate prose landed in a façade.

## 3 · Enforcement tags + the semantic anchor

Each section of the latent façade carries exactly one tag. **The tag grammar is
frozen to one form** matching what `write_zig.sh` actually emits — a rule CODE,
not a `::function` reference (v1 mixed `sh::X` and `write_zig.sh::<check>`; both
are dropped):

| Tag | Meaning | Enforced by | Eval kind |
|---|---|---|---|
| `[DETERMINISTIC → CODE]` | machine can pass/fail it | the `.sh` row for `CODE` (e.g. `FLL`, `UFS`) | prose-pinned fixture (pass + fail) |
| `[JUDGMENT → CODE]` | no script can decide; agent decides at write time | agent reading the prose | LLM-judge scenario |
| `[container]` | structural wrapper heading, not a rule | nothing — its tagged subsections carry the real codes | skipped (coherence audit §6.3) |

Walk all ~40 ZIG sections + merged gate deltas; tag each. A DETERMINISTIC tag
whose CODE has no `.sh` row is a *build-the-check* TODO; a section that genuinely
can't be checked is honestly `[JUDGMENT]`. Structural wrapper headings (e.g.
"Merged from dissolved gate cards") carry `[container]` — the sole non-rule tag —
and the coherence audit skips them; their tagged subsections carry the real codes.

**The semantic anchor (the v2 fix for "false determinism"):**
1. **Single source.** The numeric/threshold lives ONLY in the `.sh`
   (`resolver_length_gate 350`). The `.md` says "≤ the cap in
   `write_zig.sh::length`" — it carries no competing number to drift.
2. **Prose-pinned fixture.** For any rule whose prose states a bound, a fixture
   pins it: `length_351_fail.zig` MUST exit 1. If someone edits the `.sh` cap to
   500, the 351 fixture flips to pass and `resolver-evals` goes red. The
   **fixture**, not the tag, is the drift detector.

### 3.1 · Signal semantics (🟢 / 🔴 / 🔵) — and the glyph-collision fix

`HARNESS_VERIFY_OUTPUT.md:19` already defines `🟡 = violations addressed` (a
resolved-but-noted deterministic state, e.g. `LENGTH GATE | 🟡 files at cap`).
v1 reused `🟡` for "judgment open question" — the **opposite** semantics (open vs
resolved). v2 introduces a distinct glyph so one symbol never carries two
meanings:

| Signal | Meaning | Agent MUST | Exit |
|---|---|---|---|
| 🟢 GREEN | deterministic check passed | proceed | 0 |
| 🔴 RED | deterministic check failed | STOP, fix code, re-run | 1 (blocks) |
| 🟡 YELLOW | deterministic violation **addressed** (informational) | note it; existing meaning, unchanged | 0 |
| 🔵 DECIDE | judgment-only rule; no script can decide | read linked §, make the call, **state the verdict in chat** | 0 (does NOT block script) |

**Why a new glyph, not re-glyphing `🟡`:** re-glyphing the established
"violations addressed" cells touches an audited doc and retrains every agent on a
symbol they already know. `🔵` is additive — a new concept gets a new glyph. The
fix still requires a one-line `HARNESS_VERIFY_OUTPUT.md` legend update and an
`AGENTS_INVARIANCE.md` question pinning `🔵` (§8, §13).

**🔵 blocks the TURN, not the script** — see §11 for how that is made auditable
rather than honor-only.

## 4 · Two worked gates (the concrete shape)

**GATE 1 — LENGTH (deterministic, single-source threshold):**
```
write_zig.md §Length:
  - `.zig` ≤ the cap in write_zig.sh::length; split by concern when over.
    [DETERMINISTIC → FLL]   (the number lives in the .sh, not here)
write_zig.sh:  resolver_length_gate 350
fixture:  length_351_fail.zig → exit 1   (pins the prose bound; flips if cap moves)
run:  FLL 🔴 File & Function Length Limits — foo.zig: 360 (cap 350) — split
→ machine decides. pass/fail. prose carries no drift-able number.
```

**GATE 2 — TAGGED-UNIONS (judgment, no script):**
```
write_zig.md §Tagged unions for result types:
  - Result with distinct failure modes → union(enum) w/ payload, not
    optional-field struct. Callers need the *reason*, not the verdict.
    [JUDGMENT → TGU]
write_zig.sh:  resolver_judgment "TGU" "result w/ failure modes? union(enum)…"
eval:  scripts/llmevals — scenario asserts union(enum), not optional struct
run:  TGU 🔵 DECIDE — result w/ failure modes? union(enum), not optional-field
→ agent decides, states verdict in chat; HARNESS VERIFY audits the attestation.
```

## 5 · Resolver set + gate disposition (all 20 mapped — no homeless gate)

| Latent façade (.md) | Deterministic façade (.sh) | Triggers |
|---|---|---|
| `write_zig.md` | `write_zig.sh` | `*.zig` |
| `write_ts_adhere_bun.md` | `write_ts_adhere_bun.sh` | `*.ts *.tsx *.js *.jsx` |
| `write_sql.md` | `write_sql.sh` | `schema/*.sql` |
| `write_any.md` | `write_any.sh` | any source (cross-cutting authoring rules) |

**Disposition taxonomy — all 20 mapped; 15 dissolve, 5 stay (NOT emptied):**

- **(A) Language-authoring gates → that language's façade.** `zig`, `pub-surface`,
  `lifecycle` → `write_zig`; `ui-substitution`, `design-token` → `write_ts_adhere_bun`;
  `schema-removal` → `write_sql`.
- **(B) Cross-cutting authoring gates → `write_any`.** `file-length`, `logging`,
  `milestone-id`, `error-registry`, `ufs`, `greptile`, and the legacy-workaround
  family (`nlr`, `nlg`, `legacy-design`). **Principle (not a junk drawer):**
  `write_any` holds *language-agnostic authoring invariants that apply identically
  to every source file* — literal hygiene, length, observability, milestone-free
  naming, dead-code/legacy. The discriminator vs (C): (B) is checked **per file at
  write time**; (C) governs the **lifecycle/process**, never a single file's bytes.
- **(C) Process / meta gates → STAY as `docs/gates/` bodies (NOT dissolved).**
  `verification`, `invariance-suite`, `spec-template`, `architecture`, `doc-read`.
  **Why they keep their `docs/gates/` cards (not inlined into `AGENTS.md`):**
  `AGENTS.md` is 28744 / 29696 bytes — ~950 bytes headroom; five bodies cannot fit.
  So `docs/gates/` is **never emptied** — it retains exactly these five cards. This
  is also what de-fangs the "disk_count → 0 fails the parity check" risk (§9).

**The new parity invariant (the hard part v1 hand-waved).** `audit-agents-md.sh`
check #9b becomes: `AGENTS.md dispatch-rows == (retained docs/gates/ bodies = 5)
+ (resolver façades = 4)`, and the empty-set guard (`:177`) flips from "≥1 gate
body" to "exactly the 5 process bodies present." `REQUIRED_GATES` (audit-data.sh)
splits into `REQUIRED_PROCESS_GATES` (5) + `REQUIRED_RESOLVERS` (4). No gate is
homeless, none double-homed, and the audit counts a well-defined mixed end-state.

## 6 · EVALS — both spaces + two new proofs

### 6.1 Deterministic façade evals — prose-pinned fixtures
```
scripts/resolver-evals/fixtures/
  length_350_pass.zig    → write_zig.sh expects exit 0
  length_351_fail.zig    → expects exit 1   (PINS the prose bound)
  ufs_dup_string.zig     → expects exit 1
  deinit_missing.zig     → expects exit 1
scripts/resolver-evals/run.sh  → runs each fixture, diffs actual vs expected exit
```
Every `[DETERMINISTIC → CODE]` rule MUST have ≥1 pass + ≥1 fail fixture, and any
rule whose prose states a bound MUST have a fixture that pins it (§3).

### 6.2 Latent façade evals — COMPREHENSION probes (rewire the EXISTING harness)
`scripts/llmevals/run-llmevals.sh` is a **cross-agent comprehension runner**
(claude/codex/amp/opencode, `:69-78`). It grades by exact match on a
`VERDICT: YES|NO` line over `fixtures.jsonl` (`:125-174`) — it is a *comprehension*
grader, **not an adherence judge** over free-form code. v2 is honest about that:
1. **Repoint context.** `build_context()` (`:83-90`) currently cats
   `"$GATES_DIR"/*.md`. Repoint to cat **`resolvers/*.md` PLUS the retained
   `docs/gates/*.md`** (the 5 process cards, §5). Without this, `cat
   "$GATES_DIR"/*.md` dies on a changed dir. `GATES_DIR` at `:22`.
2. **JUDGMENT evals are comprehension probes, not adherence proofs.** A probe asks:
   *"given `write_zig.md`, does the model correctly answer the TGU judgment
   question (union vs optional-struct)?"* — a YES/NO the existing grader can score.
   It proves the model **understands** the rule, NOT that a real diff **adhered**.
   **Real-diff adherence is checked at `/review` + greptile, not in CI** — claiming
   a CI judge proves adherence was v1's category error. A true adherence judge
   (elicit code → rubric-grade with a pinned model) is **out of scope for v2**;
   flagged in §16 if you want it scoped later.

### 6.3 Coherence audit — `scripts/audit-resolver-coverage.sh` (honest scope)
Proves **completeness and symbol-presence** — NOT prose semantics (that's §6.1's
fixtures). Fails if any of:
- a `[DETERMINISTIC → CODE]` tag has no row for `CODE` in the `.sh`;
- a DETERMINISTIC rule has no pass+fail fixture (and, where the prose states a bound, no boundary pair that pins it — §6.1);
- a `[JUDGMENT]` rule has no comprehension probe (§6.2);
- a `.sh` CODE row has no tag in the `.md` (orphan check);
- **a CODE row delegates to a leaf helper that is absent / non-executable**
  (closes the silent-green hole, §10);
- a CODE appears in `.sh` output with no gloss-map entry (no naked codes).

### 6.4 Rule-code glosses — ONE canonical list
v1 already drifted: `lib.sh:45-61` carries codes (`FLL`/`LENGTH` duplicated;
`PUB`/`DRAIN`/`DEINIT`/`ARCH`/`XCOMPILE`) absent from the `RULES.md` legend and the
old §6.4 table. v2: **one canonical gloss list** in `RULES.md`; `lib.sh` mirrors it;
`audit-resolver-coverage.sh` fails on any divergence. Drop the `FLL`/`LENGTH`
duplicate. Delegated-only codes (`PUB`/`DRAIN`/`XCOMPILE`) get legend entries too.

### 6.5 Merge-loss proof — `scripts/audit-merge-coverage.sh` (NEW, keystone)
For each of the 15 authoring cards scheduled for deletion: assert every
non-boilerplate token-line appears in some `resolvers/*.md`, **or** is captured as
an explicit drop. **Honest scope (same discipline as §6.3):** this proves
*prose-token coverage*, NOT semantic equivalence and NOT trigger-enforcement —
that a reworded-but-faithful merge and an enforcement-orphaned trigger are *both*
risks the token scan alone won't catch. Three guards close the gameable holes the
adversarial pass flagged:
- **Frozen normalization** (not "normalized", hand-wave): lowercase → strip
  markdown punctuation/backticks → collapse whitespace → tokenize to a word
  multiset. The grammar is pinned in the script + a negative fixture proves an
  orphaned sentence FAILS.
- **No agent self-certification.** The "intentionally-dropped" branch requires an
  **Indy ack-quote** in the PR (Pull Request) body (per the deferral-discipline
  rule) — the merging agent may not author its own drop justification.
- **Trigger-surface enforcement is separate.** Each dissolved card's machine
  trigger (e.g. `milestone-id`'s `M[0-9]+_[0-9]+` regex, `ui-substitution`'s raw
  element list) must reproduce as a `.sh` CODE row, verified by §6.3's tag↔check
  wiring — token-coverage alone does not prove the trigger still fires.

A card is not deleted until its delta-landed assertion is green. Preserve any
`AGENTS_INVARIANCE.md` scenario that quotes a deleted body verbatim (§11).

## 7 · Firing planes (corrected wiring + latency)

| Plane | When | Invocation |
|---|---|---|
| Latent | EXECUTE, about to write | agent reads `write_zig.md`; runs `write_zig.sh <file>` (scoped to the touched file, NOT `--all`) |
| Anchor | HARNESS VERIFY (end-of-turn) | `write_zig.sh --staged`; 🔴 → back to EXECUTE; 🔵 → state verdict |
| Backstop | COMMIT | **`.githooks/pre-commit`** (core.hooksPath, confirmed) runs `resolvers/*.sh --staged` — **dotfiles repo only;** product repos keep the 8 leaf audits (Reading A, §10.7) |
| Audit | pre-push + `make audit` | `audit-resolver-coverage.sh` + `audit-merge-coverage.sh` wired into the SAME chain as `audit-agents-md.sh` |
| Evals | pre-push + `make` | `resolver-evals/run.sh` + (opt-in) `make llmevals` |

**Latency fix:** v1's `write_zig.sh` wired `audit-ufs.sh --all` (full-tree scan)
on every per-edit call — contradicting "instant on no-match." v2 scopes leaf runs
to `RESOLVER_FILES` (teach `audit-ufs.sh` a file-list mode; pass the staged set);
`--all` runs only on the Audit/Evals planes. State a measured latency on
`usezombie` before claiming "instant."

## 8 · In-dotfiles blast radius (PRIMARY — grounded, ~14 files)

The dissolution + rename touches the operating model's own enforcement spine.
**Every edit below lands in the Stage-2 atomic commit (§9).** Citations verified
against `feat/resolver-architecture`:

| File | Line(s) | What it pins | Must change to |
|---|---|---|---|
| `scripts/audit-agents-md.sh` | `:14` | `GATES_DIR=docs/gates` | derive from `resolvers/` |
| ″ | `:46-65` (#1) | `REQUIRED_GATES` ⊂ AGENTS.md index | resolver-set inventory |
| ″ | `:171-187` (#8) | gate bodies; **`:177` empty-set guard** | resolver-body completeness |
| ″ | `:190-209` (#9b) | parity `index==disk==REQUIRED` | resolver parity |
| ″ | `:263-277` | both hooks must grep `docs/gates` | grep `resolvers/` |
| ″ | `:130-133` | `DOTFILES_RESIDENT` docs exist | new resident paths |
| `scripts/audit-data.sh` | `:36-46` | `REQUIRED_GATES` name array | resolver set |
| ″ | `:70-78` | `DOTFILES_RESIDENT` (ZIG/BUN/greptile RULES) | `resolvers/*.md` |
| ″ | `:94-118` | `NAMED_SCENARIOS` 1:1 w/ invariance | mirror scenario edits |
| `.githooks/pre-commit` | trigger glob | gates `AGENTS.md`/`docs/gates` edits | add `resolvers/` |
| `.githooks/pre-push` | `:72` + guard | message + `docs/gates` guard | repoint + reword |
| `scripts/llmevals/run-llmevals.sh` | `:22`, `:83-90` | `build_context` cats `docs/gates/*.md` | cat `resolvers/*.md` |
| `scripts/test-audit-agents-md.sh` | `:39,46,165-167` | sandbox builds `docs/gates`+RULES; negative case asserts hook bites on dropped `docs/gates` | rewrite sandbox + negatives for resolver model |
| `bin/sync-agents` | `:35,37,45` | propagates `ZIG_RULES`/`BUN_RULES`/`docs/gates` → product repos | repoint + **add `resolvers/`** |
| `AGENTS.md` | `:66,212` | `*.zig`→ZIG_RULES; /review→ZIG_RULES | →`write_zig.md` + Resolver Dispatch table |
| `docs/EXECUTE_DOC_READS.md` | `:11,12` | zig→ZIG_RULES, ts→BUN_RULES | →façades |
| `docs/greptile-learnings/RULES.md` | `:42,91` | cross-ref ZIG_RULES sections | →`write_zig.md` |
| `docs/LIFECYCLE_PATTERNS.md` | `:3,311` | sister-doc refs ZIG_RULES | →`write_zig.md` |
| `docs/LOGGING_STANDARD.md` | `:193,195,263,283-285` | BUN_RULES §9/§10, ZIG_RULES | →façades |
| `docs/TEMPLATE.md` | `:139,142,154,356` | ZIG/BUN doc-read rows | →façades |
| `docs/ZIG_RULES.md` | `:415` | refs BUN_RULES §2 | →`write_ts_adhere_bun.md` (intra-rename) |
| `scripts/audit-logging.sh` | `:152` | fail message cites `BUN_RULES §10` | →`write_ts_adhere_bun.md §logging` |
| `skills/kishore-spec-new/SKILL.md` | `:63` | names `ZIG_RULES.md`/`BUN_RULES.md` as per-surface rule files | →façades (verify sync scope before assuming it ships to product repos) |
| `docs/HARNESS_VERIFY_OUTPUT.md` | `:19,26-36` | `🟡 = violations addressed` | add `🔵 DECIDE` legend + JUDGMENT row (§11) |

**Magnitude:** ~30+ edits across ~16 files, all in one atomic commit. This is the
work v1 never scoped — it is the dominant cost, not a footnote.

**Completeness is machine-enforced, not trust-the-table.** A
`zero-dangling-ref` audit gates Stage 2: `grep -rIl 'ZIG_RULES\|BUN_RULES\|docs/gates/[a-z-]*\.md'`
across the tree (minus this doc, git history, and the 5 retained process cards)
must return **zero** hits. The table above is the human map; the grep is the gate
— it catches any ref site (like `audit-logging.sh` / `SKILL.md`) the table missed.

**Product-repo files are out of scope (Reading A — Indy, confirmed).** This
inventory is dotfiles-only: no product repo's `make/harness.mk` or
`.githooks/pre-commit` is edited by the migration. The 8 leaf audits remain each
repo's commit-plane + harness enforcement and reach it as `sync-agents`
**symlinks**, so the one in-scope leaf edit (`audit-logging.sh:152`, fail-message
repoint) propagates with **zero product-repo commit**. Resolvers ship to product
repos as **agent-facing files only** (§10.7) — never wired into a product Makefile
or hook.

## 9 · Migration plan — staged, non-destructive (the keystone fix)

The Invariance Suite Gate is **no-override** and derives the gate set from disk
with 3-way parity, so any intermediate state where `docs/gates/` is half-gone
fails `make audit` — which the hooks run unconditionally, blocking the very commit.
v2 therefore **never lets `make audit` go red mid-flight**:

**Stage 0 — Scaffold (purely additive; gates + RULES untouched).** Create
`resolvers/{lib,write_zig,write_ts_adhere_bun,write_sql,write_any}.{sh}` and the
`.md` façades (merge ZIG_RULES + gate deltas) ALONGSIDE the still-present
`docs/gates/` and `docs/ZIG_RULES.md`. Add `scripts/resolver-evals/`,
`audit-resolver-coverage.sh`, `audit-merge-coverage.sh`. **`make audit` stays
green** (nothing removed). One or more commits.

**Stage 1 — Prove equivalence (still additive).** `audit-merge-coverage.sh` green
(every gate-card delta landed in a façade). `resolver-evals/run.sh` green.
`make llmevals` green against the new resolver context. Resolvers and legacy gates
both present and passing. **`make audit` stays green.** Commit.

**Stage 2 — Atomic switchover (the ONLY harness-editing commit → Indy sign-off).**
In ONE commit: all §8 edits + zero-dangling-ref grep green + `git mv
docs/ZIG_RULES.md resolvers/write_zig.md` (and BUN) + `git rm` the **15 authoring
cards only** (the 5 process cards STAY, §5; only after §6.5 green) + AGENTS.md
gate-index → Resolver Dispatch (4 rows) + slimmed 5-row process-gate index +
`sync-agents` repoint & resolver-add.

**Why atomic IS green (the fresh-eyes "impossible" objection, resolved).** The
pre-commit hook runs the *worktree's* `audit-agents-md.sh` against the *worktree*.
In this single commit the rewritten audit AND the new tree are both
staged-and-saved together, so the **new** parity check (`5 process + 4 resolvers`,
§5) evaluates the **new** state — never the old check against a half-migrated tree.
`docs/gates/` is never emptied (5 cards stay), so the `:177` empty-set guard is
satisfied throughout. Run `make audit && make test-audit` as a **pre-flight on the
fully-staged worktree** before `git commit`; the hook then re-confirms. No
`--no-verify`, ever.

**Rollback.** Stages 0–1 are additive → nothing to revert. Stage 2 is one commit →
`git revert` restores the full prior spine (gate cards live in git history; the
merge was additive prose, so reverting loses no rule). No kill-switch needed
because no destructive state exists before Stage 2.

**Per Hard-Safety:** Stage 2 edits `audit-*.sh` + hooks (a harness/gate) → it
requires **explicit Indy sign-off naming the files + reason**, captured in the PR
Session Notes. The agent does not switch over unilaterally.

## 10 · Execution-location & cross-repo delivery

**The problem v1 ignored — and the symlink twist the adversarial pass caught:**
`resolver_resolve_files --staged` discovers files via `git -C "$RESOLVER_ROOT"`,
where `RESOLVER_ROOT` is derived from `BASH_SOURCE` (`lib.sh:35`). But
**`bin/sync-agents` SYMLINKS** (`ln -s`, confirmed `:160,176`) — it does not copy.
So a resolver "shipped" into `usezombie` is a symlink back to
`~/Projects/dotfiles/resolvers/`, and a `BASH_SOURCE`-derived `RESOLVER_ROOT`
resolves to **dotfiles**, not `usezombie` — the Zig checks scan dotfiles' empty
tree and pass **vacuously**, exactly the bug propagation was supposed to cure.

**v2 model — separate the two roots `lib.sh` currently conflates:**
1. **`RESOLVER_HOME`** (where the scripts live, for `source lib.sh` + finding
   `scripts/`) — from `BASH_SOURCE`. Follows the symlink to dotfiles; that's
   correct for *locating the code*.
2. **`TARGET_ROOT`** (the repo being checked, for `--staged` git discovery AND the
   leaf-check scope) — from **`git rev-parse --show-toplevel`** of the CWD (or the
   file arg's dir). This resolves to `usezombie` when the symlinked resolver is run
   from inside `usezombie`, so discovery and the leaves (`audit-ufs.sh` etc., which
   already root off `--show-toplevel`) **agree on the same repo**. Robust whether
   sync copies or symlinks.
3. **Ship resolvers into each product repo via `bin/sync-agents`** (add a
   `resolvers:resolvers` entry to the link list). With (2), the symlink is now safe.
4. **Dotfiles = source-of-truth + fixture/eval host**, not where Zig checks run on
   real code. `scripts/resolver-evals/` fixtures are the only place these checks
   are provable in dotfiles (it has no `*.zig`).
5. **`resolver_run_helper` hard-fails (🔴, `RESOLVER_RC=1`) on an absent
   DETERMINISTIC helper** — never `⚪`/exit 0. `⚪` is reserved for
   `resolver_delegate`. `audit-resolver-coverage.sh` enforces helper presence (§6.3).
6. Add a `sync-agents` propagation test + a **staleness note:** symlinks are always
   current; a product-repo *real-file* override triggers sync-agents' existing
   warn-and-skip (`:171`) — flagged, not silent. Add `resolvers/*.md` to
   `DOTFILES_RESIDENT`.
7. **Product repos are NOT rewired (Reading A — Indy, confirmed).** `sync-agents`
   ships `resolvers/{*.md,*.sh}` into each product repo as **agent-facing files**
   (read at EXECUTE; runnable on a touched file) — but **no product repo's
   `make/harness.mk` or `.githooks/pre-commit` is edited.** The 8 leaf audits
   (`audit-ufs` … `audit-msid-ui`, symlinked in) stay each repo's codebase-wide
   mechanical net; resolvers are the per-file authoring lens + the dotfiles-side
   coherence/merge audits (§6.3/§6.5). The §7 Backstop plane is therefore
   **dotfiles-only** — it fires against `scripts/resolver-evals/` fixtures (dotfiles
   has no real `*.zig`/`*.ts`), which keeps the §8 zero-dangling-ref grep and the
   Stage-2 sign-off scoped to dotfiles.

## 11 · JUDGMENT enforcement — honest, and made auditable

`resolver_judgment` prints a `🔵` row and exits 0. No script can decide a taste
question, and faking determinism on one is the anti-goal. So the claim is scoped
honestly: **DETERMINISTIC rules are proven; JUDGMENT rules are attested.** v2
makes the *attestation* auditable rather than pure honor-system:

- Add a **JUDGMENT row to `HARNESS_VERIFY_OUTPUT.md`** (`HARNESS_KEYS` in
  `audit-data.sh:62-67`). **Honest scope:** the audit check is `grep -qF "$kw"
  AGENTS.md` (`audit-agents-md.sh:117`) — it verifies the row *exists* in the prose
  (so HARNESS VERIFY always lists a judgment line), NOT that a *specific turn*
  answered its `🔵`. Per-turn answering is **not machine-checked** — claiming
  otherwise was the overclaim the coverage pass flagged.
- **The machine backstop is the deferred ledger, not this row.** A turn-scoped
  verdict ledger that `pre-commit` refuses until each `🔵` has a `CODE: applied|N/A`
  ack is the only thing that mechanically blocks an unanswered judgment. Deferred
  to §16 Q1 — without it, judgment adherence is attested + comprehension-probed
  (§6.2), not enforced. Stated plainly, not dressed up.
- **Cross-agent caveat:** headless non-Orly agents (codex/amp/opencode) emit `🔵`
  to stdout with no chat audience; the comprehension probe (§6.2) is the only
  signal for them. The turn-verdict ritual is interactive-Orly best-effort.

**Invariance-questionnaire migration (part of Stage 2).** Dissolving the 15
authoring cards can strand `AGENTS_INVARIANCE.md` scenarios that assert facts about
those bodies. Before deletion: `grep` the questionnaire for every scenario that
(a) quotes a dissolved body verbatim, (b) requires a per-body structural section
(the review flagged a `Scope (M70)` requirement), or (c) triggers on "edits any
`docs/gates/*.md`". Each must be **relocated, retired, or rebased onto the façade
with an Indy ack** so it stays answerable-YES. The review named ~7.10/13.1/14.5/
22.4/23.1 — **confirm exact IDs at execution** (the grep is the source of truth,
not these numbers). `NAMED_SCENARIOS` parity (`audit-data.sh:94-118`) keeps the
keyword count honest but does not make a YES answer true — that's manual.

§1/§9 language is downgraded accordingly: "proven, not promised" holds for the
DETERMINISTIC half; the JUDGMENT half is "attested + eval-sampled."

## 12 · Invariants (code-enforced)

1. One verdict format — all `.sh` source `lib.sh`.
2. **No missing symbol** (not "no drift") — coherence audit (§6.3).
3. **No threshold drift** — single-source value + prose-pinned fixture (§3, §6.1).
4. Determinism — caps intrinsic to file content, never git history.
5. Every rule classified — no untagged section (audit-enforced).
6. Every rule evaluable — DETERMINISTIC→fixture, JUDGMENT→judge (audit-enforced).
7. No rule lost on merge — `audit-merge-coverage.sh` (§6.5).
8. No naked codes — one canonical gloss list (§6.4).
9. No silent green — absent DETERMINISTIC helper → 🔴 (§10).
10. One glyph, one meaning — `🟡` addressed, `🔵` decide (§3.1).

## 13 · Acceptance criteria

**Resolver assets**
- [ ] `resolvers/{lib,write_zig,write_ts_adhere_bun,write_sql,write_any}.{sh}` exist
- [ ] `resolvers/{write_zig,write_ts_adhere_bun,write_sql,write_any}.md` exist; every § tagged; thresholds single-sourced in the `.sh`
- [ ] `file-length` fn≤50 / method≤70 sub-cap **implemented as a leaf check OR honestly tagged `[JUDGMENT]`** — named explicitly, not collapsed into "300/350"
- [ ] glyph `🔵 DECIDE` defined; `🟡` left as "violations addressed"

**Evals & proofs**
- [ ] `scripts/resolver-evals/` fixtures: every DETERMINISTIC rule pass+fail; every prose bound pinned
- [ ] `scripts/llmevals/` JUDGMENT scenario per rule; `build_context` repointed to `resolvers/`
- [ ] `scripts/audit-resolver-coverage.sh` clean (tags↔checks↔evals↔helper-presence↔glosses)
- [ ] `scripts/audit-merge-coverage.sh` clean (every deleted card's delta landed)
- [ ] one canonical gloss list (`RULES.md` ↔ `lib.sh`); `FLL`/`LENGTH` dup removed

- [ ] `resolvers/lib.sh`: `RESOLVER_HOME` (BASH_SOURCE) vs `TARGET_ROOT` (`git rev-parse --show-toplevel`) split (§10); absent DETERMINISTIC helper → 🔴 not ⚪/0
- [ ] `docs/EXECUTE_DOC_READS.md`: doc-reads trigger rows for the NET-NEW façades (`write_sql.md`, `write_any.md`), not just repointed zig/ts rows

**Harness rewrites (first-class; Stage-2; Indy sign-off)**
- [ ] `audit-data.sh`: `REQUIRED_GATES` → `REQUIRED_PROCESS_GATES` (5) + `REQUIRED_RESOLVERS` (4); `DOTFILES_RESIDENT`→`resolvers/*.md`; `NAMED_SCENARIOS` mirrors invariance edits
- [ ] `audit-agents-md.sh`: checks #1/#8/#9b derive the mixed end-state; parity `index == 5 process bodies + 4 resolvers`; empty-set guard → "exactly the 5 process cards present"; hook-trigger check greps `resolvers/` + `docs/gates/`
- [ ] `.githooks/pre-commit` + `pre-push` repointed (NOT `.git/hooks/`)
- [ ] `scripts/test-audit-agents-md.sh` rewritten: sandbox + negative cases prove the NEW coherence audit bites
- [ ] `HARNESS_VERIFY_OUTPUT.md` JUDGMENT row + `🔵` legend; `AGENTS_INVARIANCE.md` question pinning `🔵` and the resolver model
- [ ] `bin/sync-agents` repointed + `resolvers:resolvers` added + propagation test

**Migration & references**
- [ ] Stage 0/1 commits keep `make audit` green; Stage 2 atomic; rollback note in PR
- [ ] `zero-dangling-ref` grep gate green (§8) — machine-enforced, not trust-the-table
- [ ] invariance-questionnaire migration done: stranded scenarios relocated/retired/rebased with Indy ack (§11)
- [ ] all §8 sibling-doc references repointed in the Stage-2 diff (incl. `audit-logging.sh`, `SKILL.md`)
- [ ] cross-repo (`usezombie`) refs resolved via `sync-agents` propagation (§10)
- [ ] `make audit` + `make test-audit` ALL CHECKS PASSED at Stage-2 boundary + invariance signoff

## 14 · Failure modes → mitigations

| Failure | Mitigation |
|---|---|
| `.md` prose value drifts from `.sh` | single-source threshold + prose-pinned fixture (§3) — not the tag |
| DETERMINISTIC helper deleted/renamed → silent green | `resolver_run_helper` → 🔴; coherence audit asserts helper presence (§10) |
| `make audit` red mid-migration blocks the commit | staged, additive migration; red only conceivable inside the one atomic Stage-2 commit (§9) |
| Unique gate prose lost on merge | `audit-merge-coverage.sh` blocks deletion until delta lands (§6.5) |
| `llmevals` dies on empty `docs/gates/` under `set -e` | `build_context` repointed to `resolvers/` in Stage 2 (§6.2, §8) |
| Resolver never reaches `usezombie` | added to `sync-agents`; resolvers ship into product repos (§10) |
| `🔵` judgment silently ignored | HARNESS VERIFY JUDGMENT row audited; LLM-judge eval samples adherence (§11) |
| Glyph ambiguity | `🟡` and `🔵` disjoint, pinned by invariance question (§3.1) |
| Backstop never runs on fresh clone | wired to `.githooks/` (core.hooksPath), not `.git/hooks/` (§7) |

## 15 · Discovery (consult log)

- **Façade-pair insight (Indy, Jun 04):** resolver = `.md`+`.sh` pair, not one file.
- **Merge, not rename (Indy, Jun 04):** *"latentspace `resolvers/write_zig.md`
  (merged perfected made more deterministic merge of the ZIG_RULES.md + the
  gates/\*.md relevant to zig)"* → §2: façade `.md` is a merge of ZIG_RULES + zig
  gate deltas; `zig.sh` renamed to `write_zig.sh` (the bare `zig.sh` name rejected).
- **Manifest rejected:** `.sh` is executable truth; manifest duplicates.
- **gates/\*.md dissolved selectively (v2):** authoring gates → façade; process
  gates stay in AGENTS.md (§5) — v1's "all 20 → façades" was a category error.
- **new=300/edited=350 rejected:** git-state-dependent → flat caps, intrinsic.
- **Evals in both spaces (Indy, Jun 04):** fixtures + LLM-judge + coherence audit.
- **Glosses (Indy, Jun 04):** gloss map + RULES.md legend + baked into output.
- **Adversarial CTO review (Orly, Jun 04):** 7 lenses, 38 confirmed findings
  (19 P0), verdict REWORK. v2 absorbs all P0/P1: staged migration (§9), primary
  in-dotfiles blast radius (§8), downgraded drift claim + semantic anchor (§3),
  merge-loss proof (§6.5), execution-location model (§10), glyph fix (§3.1),
  honest JUDGMENT (§11), `.githooks` wiring (§7).
- **Decisions made this turn (Orly, pick-and-proceed):** (a) `🔵` for judgment
  rather than re-glyph `🟡` — additive, lower blast radius; (b) staged migration
  over single atomic diff — keeps `make audit` green and gives free rollback;
  (c) resolvers ship into product repos via `sync-agents` — the only way the Zig
  checks run against real `*.zig`. Indy to confirm or redirect.
- **Stage-2 sign-off (Indy, Jun 04, 2026):** *"stage-2 yes signed off"* — context:
  authorizes the Stage-2 atomic switchover to edit `audit-*.sh` + `.githooks` (a
  harness/gate), satisfying the Hard-Safety harness-patch rule. The `🔵` glyph and
  the JUDGMENT ledger remain open (§16, Q1/Q2).

## 16 · Decisions (was: open questions)

1. **JUDGMENT hardening — DEFERRED** (Indy, Jun 04, 2026: *"I defer the ledger,
   its complicated"*). v2 ships judgment as **attested + comprehension-probed**
   (§11); the turn-scoped verdict ledger is a possible later hardening, not v2 scope.
2. **`🔵` glyph — pending confirm** (default: accept `🔵 DECIDE`, leaving `🟡` as
   "violations addressed"; alternative is re-glyphing `🟡` in
   `HARNESS_VERIFY_OUTPUT.md`). Cosmetic/semantic only — a colored-circle swap.
3. **Stage-2 sign-off — GRANTED** (Indy, Jun 04, 2026, §15): the Stage-2 atomic
   switchover may edit `audit-*.sh` + `.githooks` per the Hard-Safety harness-patch
   rule.
4. **Code length cap = 350 — RECONCILED** (Indy, Jun 04, 2026): the file-length
   gate card's `350` is canonical for all code (`.zig`/`.ts`/`.tsx`/`.js`/`.py`/
   `.rs`/`.go`/`.sql`). `write_zig.sh`'s stray `300` corrected to `350`; the §3/§4/
   §6.1 examples regenerated at `350`/`351`. Every resolver's `resolver_length_gate`
   equals the gate's `350`, so the early-warning never diverges from enforcement.
5. **`.md` doc/spec length caps — DEFERRED** (Indy, Jun 04, 2026): `.md` stays
   exempt from the length gate (status quo). The long merged façades (`write_zig.md`
   654L, `write_ts_adhere_bun.md` 486L) are therefore legal. Tiered doc/spec caps
   (e.g. docs 350 / specs 400) are a possible post-Stage-2 task, not v2 scope.
