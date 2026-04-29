---
name: kishore-babysit-prs
description: |
  Async polling layer on top of gstack's greptile-triage helper. Fires after
  every push to a PR, schedules re-polls per a backoff cadence, walks every
  greptile review id (not just the first), classifies via gstack's
  greptile-triage.md, suppresses against per-project + global
  greptile-history.md, and stops on two consecutive empty polls.

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
`greptile-triage.md` — open and follow it; do not paraphrase from
memory. This skill never duplicates the triage helper's logic.

## STEP 0 — Open greptile-triage.md every cycle

Before doing anything else in a polling cycle, read the triage helper:

```bash
GREPTILE_TRIAGE="$HOME/.local/share/gstack/review/greptile-triage.md"
[ -r "$GREPTILE_TRIAGE" ] || GREPTILE_TRIAGE="$HOME/Projects/dotfiles/.unified-skills/review/greptile-triage.md"
[ -r "$GREPTILE_TRIAGE" ] || { echo "BABYSIT: greptile-triage.md missing — abort cycle"; exit 1; }
```

Then walk it section by section:

| Triage section | What this skill triggers |
|---|---|
| `## Fetch` | Run verbatim per detected review id (multi-review loop below) |
| `## Suppressions Check` | Read `$HOME/.gstack/projects/<slug>/greptile-history.md`; skip lines tagged `fp` matching `repo + file-pattern + category` |
| `## Classify` | Read file ±10 lines around each comment's `path:line`; classify VALID & ACTIONABLE / VALID BUT ALREADY FIXED / FALSE POSITIVE / SUPPRESSED |
| `## Reply APIs` | Tier 1 first response, Tier 2 on greptile re-flag |
| `## Reply Templates` | Use Tier 1 / Tier 2 template verbatim — do not invent new wording |
| `## Severity Assessment & Re-ranking` | Re-rank greptile's severity against the project's actual risk profile |
| `## History File Writes` | Append to BOTH per-project and global history files (see below) |
| `## Output Format` | Use the triage helper's report shape, augmented with our cadence line |

If the triage helper is missing on the host, abort with `BABYSIT: greptile-triage.md missing` rather than guessing — the abort is visible, a silent re-implementation is not.

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
# 1. Detect repo + PR (also referenced by greptile-triage.md "Fetch")
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')
PR_NUMBER=$(gh pr view --json number --jq '.number')

# 2. Derive history paths — both files are gstack convention; the
#    triage helper's Suppressions Check + History File Writes both
#    expect them.
REMOTE_SLUG=$(~/.claude/skills/gstack/browse/bin/remote-slug 2>/dev/null \
              || basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
PROJECT_HISTORY="$HOME/.gstack/projects/$REMOTE_SLUG/greptile-history.md"
GLOBAL_HISTORY="$HOME/.gstack/greptile-history.md"
mkdir -p "$(dirname "$PROJECT_HISTORY")" "$(dirname "$GLOBAL_HISTORY")"

# 3. Walk EVERY review id — greptile may post more than one review
#    per push. The default agent failure mode is processing only the
#    first. The for-loop here lives outside the triage helper which
#    fetches once per call.
REVIEW_IDS=$(gh api "repos/$REPO/pulls/$PR_NUMBER/reviews" \
              --jq '.[] | select(.user.login | test("greptile"; "i")) | .id')

for rid in $REVIEW_IDS; do
  # 4. Follow greptile-triage.md from STEP 0 above:
  #    - Fetch line-level + top-level comments for THIS review id.
  #    - Suppressions Check against $PROJECT_HISTORY.
  #    - Classify each non-suppressed comment.
  #    - Reply with Tier 1 (first response) or Tier 2 (greptile re-flag).
  #    - Append outcome to BOTH $PROJECT_HISTORY and $GLOBAL_HISTORY
  #      using the canonical line format:
  #        <YYYY-MM-DD> | <owner/repo> | <type> | <file-pattern> | <category>
  #      type ∈ {fp, fix, already-fixed}
  #      category ∈ {race-condition, null-check, error-handling, style,
  #                  type-safety, security, performance, correctness, other}
  :
done
```

**Critical: walk every review id.** Greptile may post multiple reviews per
push (one structural, one security, etc.). The triage helper fetches
once per call; the multi-review walk lives here.

## History file discipline

Every triaged comment writes one line to BOTH:

| File | Purpose |
|---|---|
| `$HOME/.gstack/projects/<slug>/greptile-history.md` | Per-project. Drives Suppressions Check on next cycle — `fp` lines suppress matching comments forever. |
| `$HOME/.gstack/greptile-history.md` | Global aggregate. Cross-project retro / pattern-mining. |

Line format (from the triage helper's "History File Writes" section):

```
<YYYY-MM-DD> | <owner/repo> | <type:fp|fix|already-fixed> | <file-pattern> | <category>
```

- **`fp`** — false positive. Suppressed on future polls.
- **`fix`** — real issue, fixed in this cycle. Not suppressed.
- **`already-fixed`** — real issue, fixed in a prior commit on this branch. Not suppressed.

The categories are a fixed set: `race-condition`, `null-check`, `error-handling`, `style`, `type-safety`, `security`, `performance`, `correctness`, `other`. Don't invent new categories — if a finding doesn't fit, use `other` and mention the actual concern in the reply, not the history line.

## After a fix lands

1. Fix the code per the triage helper's classification.
2. Re-verify with `make lint` + `make test` (or relevant tier).
3. Reply via the triage helper's "Reply APIs" section (Tier 1 / Tier 2
   templates). Include the fix SHA in the body.
4. Commit and push.
5. Append the history line(s) to both files.
6. If the finding generalizes beyond this PR (recurring pattern, new
   class of bug), capture as a named rule in the project's
   `docs/greptile-learnings/RULES.md` in the same commit as the fix.
   Otherwise the history line alone is the durable record.
7. Re-schedule the next poll using the cadence table above.

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

- `~/.local/share/gstack/review/greptile-triage.md` — fetch / classify /
  reply / suppressions / history-write mechanics. Also at
  `~/Projects/dotfiles/.unified-skills/review/greptile-triage.md`.
- `$HOME/.gstack/projects/<slug>/greptile-history.md` — per-project
  history; drives Suppressions Check.
- `$HOME/.gstack/greptile-history.md` — global aggregate.
- `docs/greptile-learnings/RULES.md` — project-level named rules
  (durable principles). New rule added here only when the finding
  generalizes; per-incident rows go to greptile-history.md.
- `~/Projects/dotfiles/AGENTS.md` — CHORE(close) skill chain step 4
  cites this skill.
- `gh api` documentation: https://cli.github.com/manual/gh_api
