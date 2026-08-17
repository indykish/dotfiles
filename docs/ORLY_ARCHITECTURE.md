# Orly architecture

Orly does two jobs. It renders one rules file, and it proves the boundary
before a Pull Request (PR) opens. What it stores where is the one thing that
has changed shape since this document was first written — see "Why it's
materialised" below; the gates section after it is unaffected.

## Topology

```text
orly/core/operating-model.md   orly/packs/**   orly/registry.json
                              │
                         bin/orly
                              │
          ┌───────────────────┴───────────────────┐
          │                                       │
   orly sync                                orly gate
          │                                       │
   AGENTS.md (repo root)                  reads git + the tree,
          │                               runs the declared commands,
   ~/.claude/CLAUDE.md ─┐                 prints green or red
   ~/.codex/AGENTS.md  ─┼─ symlinks              │
   opencode, amp       ─┘                  exit 0 or 1
```

One generated artifact on this machine: the root `AGENTS.md`. Every agent home
here links to it, so a rule edit is one commit and reaches every session in
this checkout at once — that property is local to Kishore's own machine and
unaffected by anything below.

Every other repository gets its rules a different way: `orly init` materialises
the packs its own sources select — rendered `AGENTS.md`, the rule docs, the gate
scripts, the hooks that run them — into that repository, and writes
`.oracle/orly.json` recording the engine version and every file it wrote,
alongside the repository's own packs, commands, and surfaces. `orly update` re-materialises against the currently installed engine
version; `orly doctor` reports drift between the lock and disk instead of
silently tolerating it. A materialised repository needs no checkout of this
one, on any machine, to read its own rules or run its own gates.

## Why it's materialised

An earlier model (M01) rejected storing per-repository copies: it had cost a
re-baseline commit on every edit, a SHA-256 manifest that invalidated whenever
the tool itself changed, and drift nobody caught — three of four consumer
repositories were stale anyway. The fix at the time was to derive instead of
store: one rendered `AGENTS.md`, symlinked into every agent home, with gate
scripts resolved live from this checkout via `$ORLY_ROOT`.

That traded the storage cost for a distribution cost undiscovered until a
second engineer tried to install the harness without this checkout present —
the symlink and `$ORLY_ROOT` both require a copy of `~/Projects/dotfiles` at a
known path, which is exactly what a fresh machine, a Continuous Integration
(CI) runner, or a remote fleet container does not have. `orly init` (M03)
restores storage, but not the failure mode that got it removed: `orly update`
turns a rule change into one command per repository instead of the manual
sync M01 rejected, and the lock makes staleness a reported condition —
`orly doctor` — instead of a silent one. cache-kit.rs is the evidence for both
failure modes in the same repository: its `.oracle/` snapshot from the
pre-thin model sat frozen for four weeks with no update path, and its
generated `AGENTS.md` told a Rust crate its project name was `agentsfleet` —
a persona/product leak M03 also closes, by fencing both behind opt-in packs a
a repository without those sources never selects.

`orly verify --all` still re-renders each pack set twice and compares, then
compares the committed root `AGENTS.md` against a fresh render — that
determinism proof is unchanged by any of this.

## Gates

`orly gate` runs three groups in order and stops at the first red one.

| Gate | Proves |
|---|---|
| `work` | branch is not the default; tree is clean; the repository declares its commands in `.oracle/orly.json` |
| `verify` | Dimensions marked DONE (when a spec exists); `conform`; the fast `verify.*` commands |
| `pr` | tree clean; branch pushed; spec gate + closed-spec follow-through (`spec.moved` / `spec.baseline` / `spec.ordering` / `spec.deferrals`); docs updated for user-surface changes; the slow suites |

Every criterion is mechanical — it reads an exit code or a file. Claims that
cannot be proven that way stay prose and are graded by the spec's rubric; they
never become fake criteria.

Four behaviours worth knowing:

- **No spec, no problem — but closing is not escaping.** Spec criteria skip
  with a printed reason, so an ad-hoc bug fix meets the quality gates without
  being told to write a spec. A spec moved to `done/` on the branch is still
  discovered through its `Branch:` header and gates the PR — CHORE(close)
  never skip-passes the criteria it exists to satisfy. Two active specs is an
  error — one stream per worktree.
- **A worktree is its repository.** `repositories.json` registers primary
  checkouts only; a linked worktree resolves through the set of checkouts git
  reports for the shared object store. Streams stay ephemeral and unregistered,
  and the declared commands still run in the worktree, never in the checkout
  that carries the registry entry.
- **Slow suites are conditional.** `verify.integration` and `verify.memory` run
  only when the branch diff carries code files.
- **The docs gate is diff-shaped.** A change under the repository's `surfaces.user`
  prefixes with no matching `surfaces.docs` change is red. Test files and the
  spec tree never count.

## Overrides

`orly override <criterion> --reason <REASON>` writes an empty commit carrying an
`Orly-Override: <criterion> (<reason>)` trailer. It is immutable once pushed,
visible in the PR, scoped to the branch by merge-base, and dead after the merge.
A red criterion with a matching trailer reports `overridden`, never green. A
malformed trailer is not an override; the gate stays red.

## Profiles

`.oracle/orly.json` names any opt-in packs, the command surface, and optionally the diff
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
