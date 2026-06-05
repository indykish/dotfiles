# Negative fixture — merge-coverage MUST flag an orphaned sentence

This file is a synthetic dissolving-card stand-in for `merge-coverage.sh
--card`. It pins the keystone guarantee: a sentence whose non-boilerplate tokens
appear NOWHERE in `dispatch/*.md` (and are not in the acked drops ledger) is a
LOST rule and MUST fail the audit. If this fixture ever passes, the merge-loss
proof has gone blind and is worthless.

## A covered line (its tokens already live in the dispatch)

Result types with distinct failure modes use a tagged union, not an optional
field struct; the file length cap is enforced before commit.

## An orphaned line (these tokens exist in no dispatch — must be flagged)

The quombulent flarnesque must zindlewop grobnatically, and every snorklewidget
shall be vorpalised by the frobnitzient grumbletonk.
