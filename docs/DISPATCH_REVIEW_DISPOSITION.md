# Dispatch Review — Finding Disposition

Date: Jun 04, 2026
Companion to `DISPATCH_ARCHITECTURE.md` (v2). Source: the 7-lens adversarial
CTO review (38 confirmed, 22 refuted) + the v2 coverage check.

Every **confirmed** finding, with its v2 disposition — so the 38 that survived
cross-examination are tracked in the repo, not just in an ephemeral run log.

- **resolved** — v2 has a concrete mechanism that closes it (section cited).
- **partial** — v2 SPECIFIES the fix; implementation is pending (**Stage 0** /
  §13 acceptance criteria). NOT a doc defect: the v1-era WIP code (`lib.sh`,
  `write_zig.sh`) has not yet been reworked to the spec. The 17 partials ARE
  the Stage-0 backlog.
- **Refuted (22, excluded here):** raised criticisms the skeptic layer disproved
  (bogus / already-handled / speculative). Not real problems — not tracked.

Coverage: **21 resolved · 17 partial · 0 unresolved · 0 regressed** (of 38).
Severity: P0 9R/10P · P1 10R/6P · P2 2R/1P.

| # | Sev | Dimension | Finding | v2 status | v2 §refs |
|---|---|---|---|---|---|
| 1 | P0 | cross-repo | Dissolving docs/gates/ hard-fails the repo's own audit (gate-parity check) — the determinism | resolved | §0, §13, §8, §9 |
| 2 | P0 | cross-repo | Dissolving gates breaks the LLM-judge eval golden-set the proposal claims to extend | partial | §13, §6.2, §8 |
| 3 | P0 | cross-repo | dispatch/write_zig.sh delegates to leaf scripts that cannot run where the dispatch lives —  | partial | §0, §10, §10.3, §13, §6.3, §7 |
| 4 | P0 | determinism-feasibility | `--staged` file discovery and leaf-check scope read two different git repos — CWD vs RESOLVE | partial | §0, §10, §10.4, §7 |
| 5 | P0 | drift-coherence | Coherence audit proves symbol presence, not rule enforcement — the central anti-drift claim  | resolved | §0, §1, §12, §2, §3, §3.1, §4, §6.1, §6.3 |
| 6 | P0 | drift-coherence | Missing leaf helper returns exit 0 with a ⚪ row — a deterministic check silently becomes a n | partial | §0, §10, §12, §14, §6.3 |
| 7 | P0 | drift-coherence | Dissolving docs/gates/ and renaming ZIG_RULES.md/BUN_RULES.md detonates the in-repo invarian | resolved | §0, §11, §8, §9 |
| 8 | P0 | ergonomics-robustness | Invariance audit's gate-parity check hard-fails the moment docs/gates/ is dissolved — the ve | resolved | §0, §13, §8, §9 |
| 9 | P0 | ergonomics-robustness | DOTFILES_RESIDENT and seven referencing docs still point at docs/ZIG_RULES.md / BUN_RULES.md | partial | §6.5, §8 |
| 10 | P0 | ergonomics-robustness | dispatch_run_helper returns 0 when the leaf script is absent — silent false-green in the rep | partial | §0, §10.2, §10.3, §12, §14, §6.1, §6.3 |
| 11 | P0 | eval-loop | §6.2 "extend existing audits/llmevals/" is a category error — the existing harness is an ex | partial | §0, §13, §6.2, §6.3 |
| 12 | P0 | eval-loop | Dissolving docs/gates/ deletes the context the existing llmevals harness embeds in every pro | resolved | §13, §14, §6.2, §8, §9 |
| 13 | P0 | eval-loop | agents-md.sh is hard-bound to docs/gates/ in four checks; dissolving the directory mak | resolved | §13, §8, §9 |
| 14 | P0 | gate-dissolution | Dissolving docs/gates/ hard-fails the no-override Invariance Suite Gate — the audit asserts  | partial | §0, §13, §5, §8, §9 |
| 15 | P0 | gate-dissolution | Cross-cutting non-language gates have no coherent home in a per-language facade model — and  | resolved | §0, §5 |
| 16 | P0 | gate-dissolution | "merge-then-delete, nothing unique dies" has no proving mechanism — the coherence audit chec | partial | §13, §14, §2, §6.5, §9 |
| 17 | P0 | yellow-mechanism | Dissolving docs/gates/ detonates the deterministic invariance audit — every gate-parity, gat | resolved | §0, §13, §8, §9 |
| 18 | P0 | yellow-mechanism | 🟡 JUDGMENT has zero machine backstop and the one prose backstop (HARNESS VERIFY) has no row  | partial | §0, §1, §11, §16 |
| 19 | P0 | yellow-mechanism | DOTFILES_RESIDENT + cross-reference + cross-agent-eval all pin docs/ZIG_RULES.md & BUN_RULES | resolved | §8, §9 |
| 20 | P1 | cross-repo | §11 cross-repo blast-radius enumeration is materially incomplete — it omits the audit/eval/s | resolved | §0, §10, §11, §13, §6.3, §8 |
| 21 | P1 | cross-repo | The negative-test harness (test-audit) copies and asserts on specific gate bodies that the d | resolved | §13, §8, §9 |
| 22 | P1 | cross-repo | AGENTS_INVARIANCE.md hardcodes docs/gates/ paths and a 'Scope (M70)' per-body requirement; d | partial | §6.5, §8 |
| 23 | P1 | cross-repo | The dispatch absorbs the FILE cap but silently drops the function/method length sub-gate the | resolved | §0, §13, §5 |
| 24 | P1 | determinism-feasibility | 🟡 'blocks the turn not the script' has no machine enforcement — the determinism anchor canno | partial | §0, §11, §3.1, §6.2 |
| 25 | P1 | determinism-feasibility | Merge-then-delete of 20 gate cards into prose will silently drop machine-relevant trigger de | partial | §0, §13, §5, §6.3, §6.5, §9 |
| 26 | P1 | drift-coherence | llmevals (latent-space eval) loses its rule context the moment gates dissolve — and the prop | resolved | §13, §14, §6.2, §8, §9 |
| 27 | P1 | drift-coherence | 'Merge-then-delete, nothing unique dies' is an unverifiable promise — no mechanism diffs gat | resolved | §0, §12, §2, §6.5, §9 |
| 28 | P1 | ergonomics-robustness | Hook path mismatch: proposal wires .git/hooks/pre-commit but the canonical, audited hook is  | resolved | §0, §13, §14, §7, §8 |
| 29 | P1 | eval-loop | 🟡 YELLOW is redefined to mean the opposite of its established meaning in HARNESS_VERIFY_OUTP | resolved | §0, §11, §12, §13, §3.1, §4, §8 |
| 30 | P1 | eval-loop | dispatch-coverage.sh asserts a scenario EXISTS, not that it is discriminating — one pa | partial | §3, §6.1, §6.3 |
| 31 | P1 | gate-dissolution | llmevals harness cat's docs/gates/*.md into every model prompt under set -e — dissolving the | resolved | §13, §14, §6.2, §6.5, §8 |
| 32 | P1 | gate-dissolution | DOTFILES_RESIDENT and EXECUTE_DOC_READS still hard-reference docs/ZIG_RULES.md and docs/BUN_ | resolved | §0, §11, §13, §8, §9 |
| 33 | P1 | gate-dissolution | The 🟡-blocks-the-turn-not-the-script mechanism has no enforcer — it relies on agent self-rep | partial | §0, §11, §16, §3.1, §6.2 |
| 34 | P1 | yellow-mechanism | The coherence audit (the proposal's keystone) does not exist and is under-specified to the p | resolved | §13, §3, §6.3 |
| 35 | P1 | yellow-mechanism | Rule-extension protocol is now violated by the proposal's own structure and the gloss map re | partial | §13, §6.4, §8 |
| 36 | P2 | cross-repo | Gloss map has a silent FLL/LENGTH duplication and the architecture-doc gloss table omits hal | resolved | §12, §13, §6.3, §6.4 |
| 37 | P2 | ergonomics-robustness | pre-commit latency: 5 dispatch each shell out to git diff + multiple full-tree audits on ev | partial | §7 |
| 38 | P2 | eval-loop | dispatch_run_helper calls ufs.sh --all on the WHOLE tree per edit, contradicting the " | resolved | §7 |

**Refuted ≠ dropped.** The 22 refuted findings were independently disproven by
a skeptic agent (try-to-refute pass); excluding them is the quality filter, not
an oversight. As Stage 0 reworks the code + adds the eval/audit scripts, the
partial rows flip to resolved.

