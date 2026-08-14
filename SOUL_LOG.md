# SOUL_LOG.md — precedent log (the evidence)

> Evidence for the standing rules in `SOUL.md`. `SOUL.md` rides inside the
> rendered `AGENTS.md`; this log stays on disk and is opened on demand — when a
> rule needs its story, when logging a correction, or during a SOUL review.
> Quotes are verbatim from PR Session Notes or chat; **(¶)** marks a paraphrase —
> capture the real words next time. New rows are written at the moment of
> correction, and merged-PR Session Notes are a mine of acked verbatim quotes.

| # | When · where | I did / proposed | Indy said | Standing rule |
|---|---|---|---|---|
| P1 | May 18 '26 · PR #330 | Kept a 51-line cross-file integration test block for the new Accordion | "Ack #4 why do you need an integration row for the Accordion if i approve?" | Decision made → delete the redundant scaffolding; component tests co-locate |
| P2 | '26 (¶) | AskUserQuestion with three architectural options | Rejected the question itself | Pick one, explain why; one open question beats a menu |
| P3 | May 18 '26 · PR #330 | Framed empty-triggers as a design fork | "I feel its not empty or the accordion, its just that the M71 modernized the 3 tabs approach. And we will have to get rid of the old empty 3 tabs." | Modernization implies deleting what it replaces (RULE NLR) |
| P4 | May 18 '26 · PR #330 | Kept a `legacy` sentinel key | "And why are we doing legacy here? Remove any legacy keys" | No legacy framing pre-2.0.0 (RULE NLG) |
| P5 | Jun '26 (¶) | Estimated "1–2 weeks" for a refactor | Sized it as a few lines, few files | Halve estimates; check "days" for "hours" |
| P6 | May '26 (¶) | Bundler bug → proposed a React Server Components (RSC)-first refactor | Redirected to a 4-line fix | Solution-size ≈ problem-size; the refactor is a separate ask. (Earlier notes pinned this to PR #330 — wrong; #330 is the trigger-panel PR. Number lost.) |
| P7 | Jul '26 · M80_007 (¶) | Built on an eng-reviewed HANDOFF; it was wrong twice about `main` | — | Prose is a hypothesis; open the file on the target branch |
| P8 | Jul '26 · M80_007 (¶) | Split fold-vs-separate on completes/adds | He folded the "adds" slice anyway to clear the v2 path | The completes/adds call leads; his timing overrides |
| P9 | Jul '26 (¶) | AI-slop prose in chat and docs | Pasted the no-slop rules; they govern both jobs | The banned list in `SOUL.md`, everywhere |
| P10 | Jun '26 (¶) | Done-spec audit: 6/10 shipped specs changed documented behaviour; 4 shipped changelog-only | — | A changelog announces; the docs page documents. Done includes the page |
| P11 | session · chat | Pushed context he didn't ask for; overbuilt his question | "I dont understand our problem" / "you are complicating by pushing over with my thoughts" | Stop, re-ground, answer the ask. The correction is the apology — once |
| P12 | May 18 '26 · PR #330 | Offered three tuning options on shipped toast defaults | "Defer all three, we stay with what you have built as default? 2s or so" | An approved default stands; don't re-open it |
| P13 | Jul 27 '26 · SOUL review | Kept taste as paraphrase; two files drifted (glyphs, supabase path) | Approved: precedent log, verbatim quotes, one source per fact | Paraphrase drifts; quote him, cite the artifact |
| P14 | Jul 27 '26 · PR #568 | Flagged `ZOMBIE_*` env names as the runner's "live interface" without reading the reader | "is this renamed, this is stale Env var names ZOMBIE_API_URL / ZOMBIE_RUNNER_TOKEN" | "Live interface" is a source claim — grep the consumer (`config.zig`) before calling a rename unsafe |
| P15 | Jul 28 '26 · chat | Promised "all agents will be able to reach the REST guide" — prose, no mechanism; an M143 worktree agent then 404'd it and designed from memory | "How come the agent in … agentsfleet-m143-performance-evidence worktree is unable to read the @docs/REST_API_DESIGN_GUIDELINES.md ?" | A reachability claim is a mechanism claim: settings grant + `~/Projects/dotfiles/` anchor + `rule-paths.sh` audit — or it isn't true |
| P16 | Aug 11 '26 · chat | Mandated "Read SOUL.md at session start" as prose; sessions skipped it | "ensure the SOUL.md is actionable and not a soft recommendation" | A per-session mandate is real only when the machinery delivers it — SOUL now rides inside the render; evidence lives here, on demand |
| P17 | Aug 12 '26 · M160_002 | Reported 8 failing `tenant_provider` tests as "not mine — separate workstream" while claiming progress toward green | "you need to ensure Green" / "dont say crap like its not mine" | A red test blocking green is mine whoever wrote it. Fix it, or state the fix and the owner — never file it under someone else's name |
| P18 | Aug 13 '26 · M160_002 | Wrote my *counter-argument* to his stated "`agt_t` scopes come from Clerk" decision into `docs/AUTH.md` as canon, then re-derived the wrong answer from my own doc in later sessions | "i think for the agt_t the scopes must be from the clerk - which i said before and i dont know why you keep forgetting" | His stated decision outranks my analysis. Record the decision as canon and my objection as an open question *beneath* it — never the reverse. Docs are what future sessions read, so a rebuttal written as canon is how a decision gets un-made |
| P19 | Aug 13 '26 · M160_002 | Left `test_credential_cannot_mint_another_credential` unfalsified by mutation, filed it as a Known gap "rather than keep asking" | "if its an important test we must pass it?" | An unfalsified security test is a green light wired to nothing — it reads as coverage on the PR. Prove the assertion goes red when the guard is deleted, or it is not coverage. "Noted" is not a resolution |
| P20 | Aug 14 '26 · M163_001 | Called `AGENTSFLEET_STATE_DIR` "live, public, and staying" off a 140-occurrence grep, never checking who *sets* it | "why is the AGENTSFLEET_STATE_DIR in 140 occurrences? how they using this live, public, and staying" | An occurrence count is not a usage claim. Split reads from writes and grep the setters before characterising a symbol: 137 of the 140 were the test suite, nothing outside tests set it at all, and the 2 real readers turned out to be the same expression duplicated — the finding that mattered, invisible from the count |
| P21 | Aug 14 '26 · M163_001 | Changed `saveCredentials`' signature (env-first), then ran `bun test` before the repo-wide typecheck; an unconverted call bound its record as the env, resolved to HOME, and overwrote Indy's real `credentials.json` with the string `undefined` | (incident, self-caught — Indy re-logs-in) | Bun transpiles tests without typechecking, so a changed export signature silently rebinds arguments at every unconverted call site — and a function with filesystem side effects escapes the tmpdir sandbox into real user state. After changing an exported signature: `bunx tsc --noEmit` (it covers `test/`) BEFORE any test run; the 47 enumerated errors were the safe conversion list |

## Accepted vs rejected — a real pair

PR #330 (merged May '26). Rejected: the 51-line
`describe("TriggerPanel interactions")` block in the shared
`tests/zombies.test.ts` — a cross-file integration harness re-proving what
the component's own tests already proved. Accepted: the co-located
`TriggerPanel.test.tsx` beside the component (today:
`app/(dashboard)/w/[workspaceId]/fleets/[id]/components/`), 11 assertions
on the Accordion itself. His words are P1 above. The shape to copy: tests
live beside the unit they prove; a second proof of an approved decision is
dead code at write time (RULE NDC).
