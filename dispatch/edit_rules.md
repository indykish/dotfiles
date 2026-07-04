# edit_rules.md — governance-edit dispatch / meta-gate (LATENT façade)

This is the prose the AGENT reads **the moment it edits the governance itself**.
It is the meta-dispatch: it watches every other dispatch entry's source-of-truth.
Its **latent half is the questionnaire at [`audits/agents-md.md`](../audits/agents-md.md)**;
its **deterministic half is [`audits/agents-md.sh`](../audits/agents-md.sh)** (run by
the git hooks), and `make llmevals` proves a live agent still complies. (This is
the former Invariance Suite gate absorbed into the dispatch model — the only
dispatch entry whose `.sh` half is the system's own self-checker.)

**Signal legend:**

- 🟢 / 🔴 — `audits/agents-md.sh` mechanically passes/fails (parity, structure).
- 🔵 DECIDE — the questionnaire's reading-comprehension layer; the agent answers
  every `audits/agents-md.md` question against the *current* AGENTS.md.

## Trigger — any Edit/Write in this session to

- `AGENTS.md`
- `audits/agents-md.md`
- any dispatch entry under `dispatch/` (the rule prose) — *replaces the old
  `docs/gates/` trigger now that gates have dissolved into dispatch*
- `audits/agents-md.sh` or `audits/fixtures/*.diff`

The trigger is **agent-self-edit**: the moment the agent itself modifies one of
these files this session, this dispatch fires. (User-only edits do not fire it
from the LLM's perspective — but the pre-push hook still gates them.)

**Override:** none from the agent side. The user MAY bypass at push time with
`SKIP_INVARIANCE_PUSH=1 git push ...`, documented with a reason in the most recent
commit message. The agent MUST NOT self-bypass.

## Required action (in-session, BEFORE declaring complete)

1. **Script layer** — run `bash audits/agents-md.sh`. If exit ≠ 0, STOP, fix the
   FAIL lines, retry. Do NOT proceed with a failing script.
2. **Questionnaire layer** — read `audits/agents-md.md` and answer every question
   against the current AGENTS.md (and dispatch prose). Each answer is YES or NO
   with the justifying line(s).
3. **Tabulated report** — emit the report (gates, rules, lifecycle, scenario
   verdicts, OVERALL).
4. **Sign-off** — only when **all questions YES** AND OVERALL is `PASS`. After the
   commit lands, write the post-commit-HEAD attestation:

   ```bash
   printf '%s  %s  PASS\n' "$(git rev-parse --short HEAD)" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     > .agents-invariance-signoff
   ```

   (Gitignored — a per-machine attestation, not tracked.)
5. **Tell the user** — surface that the sign-off was written and `git push` is
   unblocked. If any question is NO, surface the regression and STOP — the user
   decides fix-or-override.

## Sequencing relative to commit & push

1. Edit governance files → 2. script ✓ → 3. questionnaire ✓ → 4. report ✓ →
5. `git commit` (pre-commit re-runs the script, defence in depth) → 6. sign-off
written against the new HEAD → 7. `git push` (pre-push reads the sign-off; PASS +
matching SHA + < 24 h freshness → push proceeds).

## Why this dispatch exists

`AGENTS.md` + the dispatch entries are the agent's ruleset. Every other dispatch
trusts that ruleset. If it drifts silently — an entry vanishes, a trigger drops a
file class, an override path widens — every downstream dispatch is now wrong. The
script catches mechanical regressions; the questionnaire catches semantic ones
that need reading comprehension. Together they prove the ruleset still holds
*before* the bad version reaches the remote.

## Failure modes this dispatch guards against

- A dispatch entry is moved or renamed; the AGENTS.md pointer rots; agents
  silently skip it.
- An override path quietly widens ("user-only" → "auto-mode covers"); autonomy
  creep.
- The always-forbidden list shrinks (e.g. someone removes `gitleaks` enforcement).
- The skill-chain order shuffles (`kishore-babysit-prs` before `/review`).
- The HARNESS VERIFY block stops listing a dispatch row.
- `audits/agents-md.md` itself loses scenarios.

## Required output (in-session)

```
🚧 EDIT_RULES DISPATCH: <branch> @ <head-sha>
  Step 1 (script):        ✅ ALL CHECKS PASSED
  Step 2 (questionnaire): ✅ <N>/<N> YES
  Step 3 (report):        emitted
  Step 4 (sign-off):      ✅ written to .agents-invariance-signoff
```

Any 🔴 → STOP, surface, do NOT push.
