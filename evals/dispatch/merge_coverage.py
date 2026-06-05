#!/usr/bin/env python3
"""merge_coverage.py — frozen token-coverage core for merge-coverage.sh
(DISPATCH_ARCHITECTURE.md 6.5). Pinned here so the normalization grammar is a
first-class, testable artifact rather than a heredoc. The orchestrating .sh
passes card paths as argv and RES_GLOB / DROPS via the environment.

A card token is covered iff it appears in the dispatch corpus OR in the
Indy-acked drops ledger. Exit 1 if any card has an uncovered token or the
ledger carries a self-certified (un-acked) drop; else exit 0.
"""
import re, glob, os, sys

# ---- FROZEN normalization grammar (do not tune per run) --------------------
TOKEN = re.compile(r'[a-z0-9]+')          # lowercase, runs of [a-z0-9] = tokens
MINLEN = 3                                 # drop sub-3-char noise (a/an/is/to)
STOP = set("""a an the this that these those of to in on at by for with from into
over under as is are was were be been being it its their your our his her they
them you we he she i my me do does did done has have had having will would can
could should may might must shall not no nor and or but if then else when while
where which who whom whose what why how so than too very just also only own same
each any all both few more most other some such per via one two three four five
up down out off once here there about above below between after before during
until against because then now new use used using make makes made get got also
yes ya etc ie eg vs aka""".split())

# Indy ack-quote pattern (guard 2 — the agent may not self-certify a drop).
ACK = re.compile(r'Indy \(\d{4}-\d{2}-\d{2}\): ".+"')


def normset(text):
    return {t for t in TOKEN.findall(text.lower())
            if len(t) >= MINLEN and not t.isdigit() and t not in STOP}


def load_corpus():
    corpus = set()
    for f in sorted(glob.glob(os.environ["RES_GLOB"])):
        corpus |= set(TOKEN.findall(open(f, encoding="utf-8").read().lower()))
    return corpus


ONE_TOKEN = re.compile(r'[a-z0-9]+\Z')


def load_drops(path):
    # Ledger is 3-column: <card-basename><TAB><token><TAB><Indy ack>. Drops are
    # PER-CARD (a token reworded away in card A is not assumed harmless in card
    # B). Returns {card_basename: set(tokens)} plus a list of rejected lines.
    drops, bad = {}, []
    if not os.path.exists(path):
        return drops, bad
    for ln in open(path, encoding="utf-8"):
        s = ln.rstrip("\n")
        if not s.strip() or s.lstrip().startswith("#"):
            continue
        parts = s.split("\t")
        if len(parts) < 3:
            bad.append("malformed (need card<TAB>token<TAB>ack): %r" % s[:48])
            continue
        card, tok, ack = parts[0].strip(), parts[1].strip().lower(), parts[2].strip()
        if not ONE_TOKEN.match(tok):
            bad.append("%r is not a single [a-z0-9]+ token (dead drop)" % tok)
        elif not ACK.search(ack):
            bad.append("%s/%s lacks an Indy ack-quote (self-cert)" % (card, tok))
        else:
            drops.setdefault(card, set()).add(tok)
    return drops, bad


def main():
    corpus = load_corpus()
    drops, bad = load_drops(os.environ["DROPS"])
    rc = 0
    if bad:
        print("  🔴 LEDGER: %d invalid drop line(s): %s" % (len(bad), "; ".join(bad)))
        rc = 1
    for card in sys.argv[1:]:
        name = os.path.basename(card)
        carddrops = drops.get(name, set())
        uncov = sorted(normset(open(card, encoding="utf-8").read()) - corpus - carddrops)
        if uncov:
            print("  🔴 %-22s %d uncovered: %s" % (name, len(uncov), ", ".join(uncov)))
            rc = 1
        else:
            print("  🟢 %-22s fully covered (every token in dispatch or acked-dropped)" % name)
    sys.exit(rc)


if __name__ == "__main__":
    main()
