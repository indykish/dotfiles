---
name: kishore-babysit-prs
description: |
  Async polling layer on top of gstack's greptile-triage helper. Fires after
  every push to a PR, schedules re-polls per a backoff cadence, walks every
  greptile review id (not just the first), and stops on two consecutive
  empty polls. Delegates fetch / classify / reply to
  `~/.local/share/gstack/review/greptile-triage.md`.

  Use after `gh pr create`, after every `git push` to a PR, or when asked
  to "babysit", "watch greptile", "poll the PR", "watch reviews",
  "follow up on PR feedback".

  Cross-agent: Claude, Codex, OpenCode, Amp.
---

# kishore-babysit-prs

Greptile auto-reviews PRs **asynchronously**. They post as PR review
comments, not check runs, so `gh pr checks --watch` doesn't observe them.
Without explicit polling on a backoff cadence, findings land after the
human stops checking — so they get missed.

This skill is the **polling cadence + walk-every-review-id loop**. The
fetch, classify, and reply mechanics live in gstack's
`greptile-triage.md` (`~/.local/share/gstack/review/greptile-triage.md`,
also referenced by `/review` Step 2.5 and `/ship` Step 3.75). Use the
triage helper for everything except scheduling — don't duplicate it here.

## Triggers

- After `gh pr create` for a feature branch.
- After every `git push` to a branch with an open PR.
- User says: "babysit", "watch greptile", "poll the PR", "watch reviews",
  "follow up on PR feedback", "what did greptile say".

## Output contract

Per cycle, print one line:

```
BABYSIT PR #<n> @ <SHA>: poll <i> | reviews=<count> | new=<m> | actioned=<k> | next=<delay>
```

`actioned` = findings whose code fix landed in this cycle.

## Cadence (backoff)

| Time since last push (or last review) | Poll interval |
|---|---|
| 0–10 min | +180 s after each push |
| 10–30 min | +300 s |
| 30–60 min | +600 s |
| > 60 min | +1200 s, then stop after 2 consecutive empty polls |

Claude Code: use `ScheduleWakeup(delaySeconds, "re-poll greptile on PR
#<n> <SHA>")`. Other agents: `sleep <delay>` in a shell loop, or schedule
via the agent's native cron/wakeup mechanism.

## Polling loop

```bash
# 1. Detect PR (matches greptile-triage.md "Fetch" section)
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')
PR_NUMBER=$(gh pr view --json number --jq '.number')

# 2. Walk EVERY review id — greptile sometimes posts more than one review
#    per push. The default agent failure mode is processing only the first.
REVIEW_IDS=$(gh api "repos/$REPO/pulls/$PR_NUMBER/reviews" \
              --jq '.[] | select(.user.login | test("greptile"; "i")) | .id')

# 3. For each review id, follow gstack greptile-triage.md:
#    - Fetch line-level + top-level comments in parallel.
#    - Run Suppressions Check against $HOME/.gstack/projects/<slug>/greptile-history.md.
#    - Classify (Severity Assessment & Re-ranking section).
#    - Reply per Tier 1 / Tier 2 templates.
#    - Write to History File per the History File Writes section.
```

**Critical: walk every review id.** Greptile may post multiple reviews per
push (one structural, one security, etc.). The `for` loop above is
non-negotiable — gstack's triage doc fetches once per call, so the
multi-review walk lives here.

## After a fix lands

1. Fix the code per the triage helper's classification.
2. Re-verify with `make lint` + `make test` (or relevant tier).
3. Reply via the triage helper's "Reply APIs" section (Tier 1 / Tier 2
   templates). Include the fix SHA in the body.
4. Commit and push.
5. Re-schedule the next poll using the cadence table above.

## Stop conditions

- **Two consecutive empty polls** (no new reviews) → stop, report done.
- **PR merged or closed** → stop, report.
- **CI red and not from your changes** → surface to the user; pause
  polling until they decide.
- **User says stop / pause** → print one final
  `BABYSIT PR #<n>: paused per user` line and stop.

## Report format

At end of each cycle:

```
BABYSIT REPORT — PR #<n> @ <SHA>
  Polls run: <i>
  Reviews seen: <count>
  Findings actioned: <k> (P0: <a>, P1: <b>)
  Findings deferred: <d> (with reasons)
  Rules added/updated: <list of RULE refs>  # via triage helper's history-write
  Next poll: in <delay>s OR stopped (<reason>)
```

## What this skill does NOT do

- Does **not** re-implement fetch/classify/reply — see
  `~/.local/share/gstack/review/greptile-triage.md`.
- Does **not** merge the PR — use `/land-and-deploy` after greptile is
  green.
- Does **not** modify CI configuration or skip greptile.
- Does **not** apply P2/P3/nit findings without explicit user approval
  (the triage helper's classification drives this).

## Failure modes

| Surface | Action |
|---|---|
| `gh api` rate-limited | Back off the poll interval by 2× and retry next cycle |
| Greptile review missing on a push | Re-poll once at +180 s; if still missing, surface to user |
| `gh pr view` returns nothing (PR not yet visible) | Skip cycle; retry next interval |
| Multiple reviews with conflicting suggestions | Apply the union; surface conflict only if both can't coexist |
| Finding is in code the agent did not author | Surface to user before fixing — never edit changes the agent did not create |

## References

- `~/.local/share/gstack/review/greptile-triage.md` — fetch/classify/reply
  mechanics. Also at `~/Projects/dotfiles/.unified-skills/review/greptile-triage.md`.
- `~/Projects/dotfiles/AGENTS.md` — CHORE(close) skill chain step 4 cites
  this skill.
- `docs/greptile-learnings/RULES.md` — incident capture target (history
  file writes route here via the triage helper).
- `gh api` documentation: https://cli.github.com/manual/gh_api
