---
name: kishore-babysit-prs
description: |
  Babysit a pull/merge request after every push: poll greptile asynchronous
  reviews on a delay, walk every review (loop ALL ids, not just the first),
  triage P0/P1 findings against docs/greptile-learnings/RULES.md, fix the
  code, reply with the fix SHA, and re-schedule. Stops on two consecutive
  empty polls. Use after `gh pr create`, after every push to a PR, or when
  asked to "babysit", "watch greptile", "poll the PR", "watch reviews",
  "follow up on PR feedback".

  Cross-agent: Claude, Codex, OpenCode, Amp. Self-contained — no
  agent-specific tool invocations beyond the optional ScheduleWakeup hint
  for Claude Code.
---

# kishore-babysit-prs

Greptile auto-reviews PRs/MRs **asynchronously**. They land at unpredictable
intervals (typically 1–3 minutes after a push, sometimes longer). The
default `gh pr checks --watch` does NOT observe these reviews because they
post as PR review comments, not check runs. Without explicit polling, the
findings are missed and merged-anyway PRs ship with avoidable defects.

This skill encodes the polling protocol so neither memory nor judgment is
load-bearing — the loop just runs.

## Triggers

- After `gh pr create` for a feature branch.
- After every `git push` to a branch with an open PR.
- User says: "babysit", "watch greptile", "poll the PR", "watch reviews",
  "follow up on PR feedback", "what did greptile say".

## Output contract

Before/after each polling cycle, print one line:

```
BABYSIT PR #<n> @ <SHA>: poll <i> | reviews=<count> | new=<m> | actioned=<k> | next=<delay>
```

`actioned` = findings whose code fix landed in this cycle.

## Cadence

| Time since last push (or last review) | Poll interval |
|---|---|
| 0–10 min | +180 s after each push |
| 10–30 min | +300 s |
| 30–60 min | +600 s |
| > 60 min | +1200 s, then stop after 2 consecutive empty polls |

Claude Code: use `ScheduleWakeup(delaySeconds, "re-poll greptile on PR
#<n> <SHA>")` at the chosen delay. Other agents: `sleep <delay>` in a
shell loop, or schedule via the agent's native cron/wakeup mechanism.

## Polling loop

```bash
PR_NUMBER=<n>
REPO=<owner>/<repo>     # auto-detect via: gh repo view --json nameWithOwner -q .nameWithOwner

# 1. Fetch every review on this PR — loop ALL ids, not just the first.
REVIEW_IDS=$(gh api "repos/$REPO/pulls/$PR_NUMBER/reviews" \
              --jq '.[] | select(.user.login | test("greptile"; "i")) | .id')

# 2. For each review, fetch its line comments.
for rid in $REVIEW_IDS; do
  gh api "repos/$REPO/pulls/$PR_NUMBER/reviews/$rid/comments" \
    --jq '.[] | {id, path, line, body}'
done
```

**Critical: walk every review id.** Greptile sometimes posts more than one
review per push (e.g. one for diff structure, one for security). The
default agent failure mode is processing only the first review and
ignoring the rest. The `for` loop above is non-negotiable.

## Triage protocol

For each finding, classify by greptile's severity tag (`P0` / `P1` / `P2` /
`P3` / nit):

- **P0** must-fix before merge. Block on it.
- **P1** strongly recommended. Fix unless the user explicitly defers.
- **P2** nice-to-have. Surface to the user; act only on explicit ask.
- **P3 / nit** style. Batch for end-of-PR cleanup or skip.

For every P0/P1 finding:

1. Look it up in `docs/greptile-learnings/RULES.md`. If a matching RULE
   exists, append the incident reference (`Ref: PR #<n> review <rid>`) to
   the rule. If no rule matches but the finding is generalisable, draft
   a new compact rule (Rule / Why / Tags / Ref) and add it to
   `RULES.md`. **Never defer rule capture** — the rule lands in the same
   commit as the fix.
2. Fix the code. Re-verify with `make lint` + `make test` (or the
   relevant tier).
3. Reply to the review comment with the fix SHA via:
   ```bash
   gh api "repos/$REPO/pulls/$PR_NUMBER/comments" \
     -X POST \
     -F in_reply_to=<comment_id> \
     -F body="Fixed in $(git rev-parse HEAD)."
   ```
4. Commit and push.
5. Re-schedule the next poll using the cadence table.

## Stop conditions

- **Two consecutive empty polls** (no new reviews) → stop polling, report
  done.
- **PR merged or closed** → stop polling, report.
- **CI red and not from your changes** → surface to the user; pause
  polling until they decide.
- **User says stop / pause** → stop polling; print one final
  `BABYSIT PR #<n>: paused per user` line.

## Report format

At end of each polling cycle, print:

```
BABYSIT REPORT — PR #<n> @ <SHA>
  Polls run: <i>
  Reviews seen: <count>
  Findings actioned: <k> (P0: <a>, P1: <b>)
  Findings deferred: <d> (with reasons)
  Rules added/updated: <list of RULE refs>
  Next poll: in <delay>s OR stopped (<reason>)
```

## What this skill does NOT do

- It does **not** merge the PR. Use `/land-and-deploy` after greptile is
  green.
- It does **not** modify CI configuration or skip greptile.
- It does **not** apply P2/P3/nit findings without explicit user
  approval.

## Failure modes

| Surface | Action |
|---|---|
| `gh api` rate-limited | Back off the poll interval by 2× and retry next cycle |
| Greptile review missing on a push | Re-poll once at +180 s; if still missing, surface to user |
| Reply to comment fails (404) | Greptile may have deleted/edited; treat as actioned with a `(reply-failed)` note |
| Multiple reviews with conflicting suggestions | Apply the union; surface conflict to user only if both can't coexist |
| Finding is in code the agent did not author | Surface to user before fixing — RULE: never revert/edit changes the agent did not create without consent |

## References

- `~/Projects/dotfiles/AGENTS.md` — CHORE(close) skill chain step 4 cites
  this skill.
- `docs/greptile-learnings/RULES.md` — incident capture target.
- `gh api` documentation: https://cli.github.com/manual/gh_api
