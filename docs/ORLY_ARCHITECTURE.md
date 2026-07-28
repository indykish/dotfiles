# Orly architecture

Orly does two jobs. It renders one rules file, and it proves the boundary
before a Pull Request (PR) opens. It stores nothing.

## Topology

```text
orly/core/operating-model.md   orly/packs/**   orly/profiles/*.json
                              │
                         bin/orly
                              │
          ┌───────────────────┴───────────────────┐
          │                                       │
   orly sync                                orly gate
          │                                       │
   AGENTS.md (repo root)                  reads git + the tree,
          │                               runs the profile's commands,
   ~/.claude/CLAUDE.md ─┐                 prints green or red
   ~/.codex/AGENTS.md  ─┼─ symlinks              │
   opencode, amp       ─┘                  exit 0 or 1
```

One generated artifact: the root `AGENTS.md`. Every agent home links to it, so a
rule edit is one commit here and reaches every session in every repository at
once. Consumer repositories keep one hand-written `AGENTS.md` with project facts
and no copies. Their gate scripts run from `$ORLY_ROOT` (default
`~/Projects/dotfiles`); their rule pages are read from the same checkout.

## Why nothing is stored

The earlier model copied 44 files into each repository and tracked them with a
Secure Hash Algorithm 256-bit (SHA-256) manifest. It cost a re-baseline commit
on every edit, it invalidated every lock when the tool itself was refactored,
and three of four repositories were stale anyway. The manifest was also a hash
ledger inside git, which is already one.

So orly derives instead of storing. `orly verify --all` re-renders each profile
twice and compares, then compares the committed `AGENTS.md` against a fresh
render. Determinism and currency, no stored hashes.

## Gates

`orly gate` runs three groups in order and stops at the first red one.

| Gate | Proves |
|---|---|
| `work` | branch is not the default; tree is clean; the repository resolves to a profile |
| `verify` | Dimensions marked DONE (when a spec exists); `conform`; the fast `verify.*` commands |
| `pr` | tree clean; branch pushed; spec gate; docs updated for user-surface changes; the slow suites |

Every criterion is mechanical — it reads an exit code or a file. Claims that
cannot be proven that way stay prose and are graded by the spec's rubric; they
never become fake criteria.

Four behaviours worth knowing:

- **No spec, no problem.** Spec criteria skip with a printed reason, so an
  ad-hoc bug fix meets the quality gates without being told to write a spec.
  Two active specs is an error — one stream per worktree.
- **A worktree is its repository.** `repositories.json` registers primary
  checkouts only; a linked worktree resolves through the set of checkouts git
  reports for the shared object store. Streams stay ephemeral and unregistered,
  and the profile's commands still run in the worktree, never in the checkout
  that carries the registry entry.
- **Slow suites are conditional.** `verify.integration` and `verify.memory` run
  only when the branch diff carries code files.
- **The docs gate is diff-shaped.** A change under a profile's `surfaces.user`
  prefixes with no matching `surfaces.docs` change is red. Test files and the
  spec tree never count.

## Overrides

`orly override <criterion> --reason <REASON>` writes an empty commit carrying an
`Orly-Override: <criterion> (<reason>)` trailer. It is immutable once pushed,
visible in the PR, scoped to the branch by merge-base, and dead after the merge.
A red criterion with a matching trailer reports `overridden`, never green. A
malformed trailer is not an override; the gate stays red.

## Profiles

A profile names its rule packs, its command surface, and optionally its diff
surfaces:

```json
{
  "commands": { "conform": [["make", "harness-verify"]],
                "verify.unit": [["make", "test-unit-all"]] },
  "surfaces": { "user": ["src/agentsfleetd/http/", "cli/src/"],
                "docs": ["docs/"] }
}
```

Orly owns policy and invokes these commands. The repository owns what they do.

## Evidence

`orly verify --all --write-evidence` records the source commit and every check
into `.oracle/evidence.json` (git-ignored). Pre-push writes it when the pushed
range touches governance paths.
