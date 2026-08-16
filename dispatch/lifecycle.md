# lifecycle.md — stage-runbook latent façade

Read this at a lifecycle stage transition: CHORE(open), PLAN, EXECUTE onboarding,
CHORE(close), LAND, worktree setup, or milestone bootstrap. The generated
`AGENTS.md` carries each stage's binding essence; this façade carries the
runbooks — the checklists, recipes, and output formats an agent needs only at
that moment. 🤔 judgment-only — no `.sh` pair; CONFORM's deterministic gates and
`orly gate` remain the mechanical anchors.

Section-scan first (`grep -n "^## " dispatch/lifecycle.md`); read the stage you
are entering, not the whole file.

## CHORE (open) — runbook

1. Spec `docs/v*/pending/` → `active/`; `Status: IN_PROGRESS`; `Branch:` set.
2. **Test Baseline** — run `make _lint_zig_test_depth`; copy the counts into the
   spec header as `**Test Baseline:** unit=<N> integration=<M>` (VERIFY's Test
   Delta row compares against it; `~/Projects/dotfiles/docs/VERIFY_TIERS.md`
   §Test delta).
3. Create the worktree; verify CWD is inside it (`pwd` + `git worktree list`).
4. Commit the four steps on the feature branch. No code until the commit lands.

## Worktree recipe (agentsfleet)

`git checkout main && git branch feat/mNN-name && git worktree add ../agentsfleet-mNN-name feat/mNN-name && cd ../agentsfleet-mNN-name && bun install && (cd cli && bun install && bun run build)`.
The root `bun install` hydrates the workspace (`ui/packages/*`); `cli/` is its
own Bun project needing install + build. `git worktree add` fires
`.githooks/post-checkout` → symlinks `~/.config/agentsfleet/{ui,runner}.env.local`
into the tree; on 🟠 run `provision-env-1password`, re-link. Post-merge:
`git worktree remove ../agentsfleet-mNN-name`.

**Mid-stream spec → ask before hydrating (default: same tree).** A spec created
inside an active worktree → ask Indy before spinning up a second one. Indy leans
same tree: a second tree fragments the outcome and adds a PR to babysit.
Complete the outcome in place; fold new scope into the current spec/PR (reopen
`done/`→`active/` if closed) unless the work is genuinely disjoint AND Indy opts
into a separate tree.

## Bootstrap & milestone gates

- **Priming:** (1) Human runs `playbooks/founding/01_bootstrap/001_playbook.md`.
  (2) Agent runs `./playbooks/founding/02_preflight/00_gate.sh` (green before
  next). (3) Agent runs `playbooks/founding/03_priming_infra/001_playbook.md`.
  Milestones only after PRIMING_INFRA verified.
- **Credential gate** — milestones needing external creds start `M{N}_001`
  enumerating every downstream credential (name + fetch location). Fail loud
  listing all missing before any `M{N}_002+`.
- **Agent-first sequencing** — minimize human steps; post-handoff steps
  retryable + idempotent. Vault is the inter-step interface; never pass creds
  by argument/env.

## PLAN — expansions

**Quality-ceiling line** — would it be more performant / leaner / a better user
experience (fluid) / sounder under concurrency if built differently, and would a
larger refactor beat the patch? Default solution-size ≈ problem-size; "yes" →
surface option + cost, Kishore picks. Read docs when behavior is unclear.

**Surface-area checklist** — yes/no + reason each: OpenAPI changes (list paths)
· `agentsfleet` CLI · user-facing docs at `docs.agentsfleet.net` · release notes
/ version bump · schema changes (≤100 lines/file, single-concern, update
`schema/embed.zig` + migration array) · Schema Removal Guard output ·
spec-vs-rules conflict (amend spec).

## EXECUTE — spec discipline expansions

- **Golden-path before PLAN approval** — walk the concrete end-to-end with every
  lookup/data-source/secret-storage named; any `[?]` blocks the spec.
- **DONE = called in production + tested** — grep the production entry-point for
  the named symbol; no call → not DONE.
- **Changelog claim challenge** — before any `<Update>`, ask "Would this be true
  if the test file vanished?" Only test evidence (not middleware/handler/CLI) →
  claim unearned.
- **Spec → Code → Test alignment:** every Dimension → test case (no test = not
  implemented); every Interface → exact spec signature (signature change →
  update spec first); every Acceptance Criterion → verifiable command ("works
  correctly" is not a criterion; "`make test` passes" is); no code commits
  without tests (`/write-unit-test`); every Error Table row → negative test.
- **Recovery notes:** local Docker `ENOSPC` → `~/bin/mac-cleanup.sh`, verify
  `docker system df`, retry.

## CHORE (close) — required outputs

- All Dimensions/Sections `DONE` (`IN_PROGRESS` if parked); spec moved
  `docs/v*/active/` → `docs/v*/done/` iff complete.
- New `<Update>` in `~/Projects/docs/changelog.mdx` (template + version-bump
  matrix in `~/Projects/dotfiles/skills/release-template.md` — re-source each
  release, never paraphrase) **AND, re-reading the spec, the affected
  `~/Projects/docs/` pages revised to match (endpoints/CLI/flags/behavior)** —
  an `<Update>` alone is insufficient when documented behavior changes.
- `docs/architecture/**` carries a non-empty diff for flow-defining changes, or
  Session Notes says why not (`dispatch/name_architecture.md` covers both homes).
- PR `## Session notes`: decisions, assumptions, dead ends, deferrals,
  `/write-unit-test` + runtime review outcomes, `kishore-babysit-prs` final
  report.
- Orphan sweep complete (RULE ORP); ephemeral handoff docs deleted
  (`docs/**/HANDOFF_*.md`, `docs/**/handoff*.md`, `HANDOFF.md` at any depth —
  they brief the next agent, never the PR).
- Pre-commit `git status -uall` audit — every modified/untracked/
  conflict-resolved/hook-managed file staged into the CHORE(close) commit, or
  documented-as-excluded with reason in the commit body; `git status` MUST be
  empty post-commit before opening/updating the PR.
- Version sync: `VERSION` touched → `make sync-version`; commit propagated
  `build.zig.zon`/`agentsfleet/package.json`/`agentsfleet/src/cli.js`;
  `make check-version` passes.

## Deferral discipline — expansion

Any claim that a spec Section/Dimension was "deferred to follow-up" — in
`HANDOFF.md`, PR description, Session Notes, or chat — requires an
**Indy-acked verbatim quote** in PR Session Notes (or spec Discovery). Format:
`> Indy (YYYY-MM-DD HH:MM): "<verbatim ack>" — context: <which item, why>`.
Agent-unilateral deferral = incomplete scope, not deferral; CHORE(close) blocks
until the item lands or the quote is captured. **HANDOFF.md is a faithful state
report** — a pickup agent reading a HANDOFF claiming items were deferred without
ack-quotes must treat them as in-scope and surface the contradiction to Kishore
before continuing.

## Pre-PR gates

Spec in `docs/v*/done/` in diff (skip iff parked); `changelog.mdx` has a new
`<Update>` in diff (skip iff internal-only or parked); `Status: DONE` but spec
not in `done/` → do not open PR; `make check-version` passes; branch contains
`origin/main` HEAD (rebase pre-push / merge post-push —
never force-push an open PR branch).

**`orly gate pr` follows the spec through the close.** A spec moved to `done/`
on this branch is still discovered — its `Branch:` header names the branch —
and every spec criterion runs against it; skip-pass is only for genuinely
spec-less branches. Mechanical criteria: `spec.moved` (`Status: DONE` ⇒ the
spec sits under `done/` and was moved on this branch) · `spec.baseline`
(`Test Baseline:` recorded) · `spec.ordering` (the branch's first commit
carries the spec — no code before CHORE(open)) · `spec.deferrals` (a deferral
claim needs the `> Indy (` ack quote in the spec). An Indy-acked deferral that
leaves a Dimension open ships via `orly override spec.dimensions --reason
"<the ack>"` — visible in the PR, dead after the merge.

**Babysit detail:** `kishore-babysit-prs` covers all three surfaces — CI check
runs (fix every failure your diff caused), greptile inline comments, and the
PR-level summary thread — and stops on two consecutive empty polls with CI
green. Never `gh pr checks --watch` for greptile.

## LAND (after merge, or when Indy says merged)

`git checkout <default> && git pull origin <default>`; prune the merged worktree
and branch; `make down` where the repository defines it. Pending files → stash,
pull, diff against the new default; already-landed → drop.
