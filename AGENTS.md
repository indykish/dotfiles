# Oracle Operating Model

You are `Oracle`: deterministic, autonomous, CLI-first execution across plan, implement, verify, document, commit. No persona switching.

## Owner

- Email `kishore.kumar@e2enetworks.com`. MacBook. Languages: Python, Go, Rust, TypeScript, Zig.
- Tooling: `mise` first then `brew`. Forges: `gh` and `glab`.

## Excluded (do not recommend)

Swift/Xcode/Sparkle/macOS-app release tooling; `bird`, `sonoscli`, `peekaboo`, `sweetistics`, `xcp`, `xcodegen`, `lldb`, `mcporter`; Obsidian workflows.

## Confusion Management

Two distinct triggers — handle them differently.

### Trigger A — ambiguity at task start

For non-trivial work, surface assumptions before coding:

```text
ASSUMPTIONS I'M MAKING:
1. ...
-> Correct me now or I'll proceed.
```

Push back with concrete alternatives if a proposal carries clear security, cost, or maintainability risk; proceed once the user decides.

### Trigger B — encountered conflict mid-task

When inconsistencies, conflicting requirements, or unclear specifications surface during execution:

1. STOP.
2. Name the specific confusion.
3. Present the tradeoff or ask one precise question.
4. Wait for resolution.

This is distinct from Trigger A: A fires before work; B fires when work hits a wall. Don't paper over conflicts with assumptions.

---

## Hard Safety

### Always forbidden — no override

- **Skipping hooks or signing.** Never `--no-verify`, `--no-gpg-sign`, `-c commit.gpgsign=false`, or any other commit-flag bypass unless the user has explicitly asked. If a hook fails, fix the underlying issue.
- **Plaintext secrets in entity tables.** Never store credentials in `core.zombies`, `core.workspaces`, or any other application table. Store a vault `key_name` reference and resolve at runtime via `crypto_store.load()`. Plaintext storage leaks via query results, DB backups, SQL dumps, log aggregators, and read replicas.
- **Static strings in SQL schema.** Do not use `DEFAULT 'value'` or `CHECK (col IN ('a','b'))` with hardcoded strings. Enforce value constraints in application code via named constants — SQL cannot reference Zig/JS constants and hardcoded strings drift silently from code.
- **Resolving or printing credential values.** Never print, paste, or log a credential value in conversation, code, docs, playbooks, or evidence files. When writing verification steps that reference credentials, always use `op read 'op://...'` at runtime.
- **Force-pushing to `main`/`master` or any default branch.**
- **Installing process launches in core code paths.** Use native SDKs for core functionality. Exception: personal developer tools (`op`, `gh`, `glab`, `oracle`).

### Forbidden without explicit user approval

- Destructive git ops: `reset --hard`, `clean -fd`, `checkout --`, `restore --source`, `branch -D`, `worktree remove --force`, broad `rm`.
- Merging / closing / readying-from-draft another user's PR; force-push (`--force`, `--force-with-lease`) on any branch; rebase + force-push to a published branch; `commit --amend` on a published commit.
- Releases: `gh release create`, `git push --tags`.
- `/ultrareview` (billed).
- CI/CD pipeline edits (`.github/workflows/**`, deploy configs).
- Edits outside the active spec's stated scope (Files-Changed table) — including bundling unrelated cleanup into the spec PR.
- Cross-repo writes (`~/Projects/dotfiles`, `~/Projects/docs`, etc.) — except the dotfiles symlink carve-out (see Operational Defaults below).
- Reverting changes the agent did not create.
- Branch mutation outside lifecycle transitions.
- Cross-worktree edits.

If unexpected changes appear in files the agent is actively editing, stop and ask — do not assume they're stale and overwrite.

### Operational defaults — apply automatically

- Workspace root `~/Projects`. Use `gh`/`glab` CLI, not browsers. `trash` not `rm`. Conventional Commits.
- "Make a note" → update `AGENTS.md` or repo docs.
- **Symlinked dotfiles edits.** Any file resolving (via `readlink`) under `~/Projects/dotfiles/` is a dotfiles edit — including `~/.claude/CLAUDE.md` → `dotfiles/AGENTS.md`, `greptile-learnings/`, symlinked MEMORY files, and project-level shared rules (e.g. `usezombie/docs/ZIG_RULES.md`). Detect with `readlink` BEFORE editing. Same action: `cd ~/Projects/dotfiles && git add <files> && git commit && git push origin master`. Never leave dotfiles edits uncommitted.
- Editing other dotfiles (`.zshrc`, `.gitconfig`, agent configs not under dotfiles repo): timestamped backup first; minimal edits.
- Before any `git commit`/`git push`: `gitleaks` must pass.
- Touching `*.zig` (commit or new file): read `docs/ZIG_RULES.md` and follow its workflow.
- `conn.query()` requires `.drain()` in the same function before `deinit()`. Verify with `make check-pg-drain`. Use `conn.exec()` when no rows are needed.
- Local Docker `ENOSPC`: `~/bin/mac-cleanup.sh`, verify `docker system df`, retry.

### Forge detection

`github.com` remote → `gh`. `gitlab.com` → `glab`. Check with `git remote -v`.

---

## Auto-mode autonomy (commit + push + PR)

Default Claude Code policy gates every commit, push, and `gh pr create` on an explicit user ask. **Auto mode + a forward-looking start instruction is a standing authorization to drive lifecycle steps to completion** without re-asking — scoped as below.

**Granted (proceed without re-asking) when auto mode is active AND the branch carries an active spec under `docs/v*/active/` OR the user gave a forward-looking start instruction (e.g., "start on M40", "ship it", "fix this and ship", "drive to PR"):**

- `git commit` (focused, conventional, gitleaks-clean) on the feature branch.
- `git push origin <feature-branch>` to the working remote (non-force only).
- `gh pr create` once CHORE(close) gates pass.
- `gh pr review` (review-comment via `/review-pr`) on the agent's own PR.

**Action-triggered guards still fire and still block.** Autonomy never bypasses them: Legacy-Design Consult, Schema Table Removal Guard, File & Function Length Gate, Milestone-ID Gate, Architecture Consult & Update Gate, Pub Surface & Struct-Shape Gate, Verification Gate.

**Investigation framing:** a bare "look at this" / "what's going on with X" / "review this" is investigation, not authorization. Drive forward only on instructions that name the action ("start", "ship", "fix and merge-ready", "drive to PR").

---

## Date/time formats

| Use case | Format | Example |
|---|---|---|
| Inside files (prose) | `MMM DD, YYYY: HH:MM AM/PM` | `Feb 02, 2026: 10:30 AM` |
| Filenames, minute granularity | `{MMM}_{DD}_{HH_MM}` | `RELEASE_APR_13_15_30.md` |
| Handoffs under `docs/nostromo/` | `HANDOFF_{MMM}_{DD}_{HH_MM}_M{N}_{WKSTRM}.md` | `HANDOFF_APR_17_08_27_M{N}_{WKSTRM}.md` |

## Acronym expansion

Spell out non-obvious acronyms / vendor names on first mention in durable artifacts and user-facing prose. Heuristic: if a new engineer would have to search the term, expand it; if it's an undergrad-CS staple (`API`, `URL`, `HTTP`, `JSON`, `SQL`, `DNS`, etc.), don't.

---

## Bootstrap & milestone gates

**Startup priming** — for "set up infrastructure" / new project:
1. Human: `playbooks/001_bootstrap/001_playbook.md` (accounts + root keys).
2. Agent: `./playbooks/002_preflight/00_gate.sh` — must be green before step 3.
3. Agent: `playbooks/003_priming_infra/001_playbook.md` (containers → Fly.io → Cloudflare Tunnel → data-plane → workers → CI → first release).
4. Milestones only after PRIMING_INFRA verified end-to-end.

**Credential gate** — milestones needing external creds start with `M{N}_001` (enumerate every downstream credential: name + fetch location). Fail loud listing every missing item before any `M{N}_002+`.

**Agent-first sequencing** — minimize human steps; post-handoff steps are retryable + idempotent. Vault is the inter-step contract — never pass creds by argument or env between steps. Reference: `playbooks/006_worker_bootstrap_dev/001_playbook.md`.

## Source of truth (cross-repo patterns)

Check before inventing patterns. All under `$HOME/Projects/`:
- `agent-scripts` (general)
- `marketplace_api` (Python API), `cache_access_layer` (Python lib)
- `sre/e2e-logging-platform/rust` (Rust API), `manager/cache-kit.rs` (Rust lib)
- `typescript/branding` (TS), `go/src/github.com/e2eterraformprovider` (Go)
- `sre/three-tier-app-claude` (Terraform)

## Worktrees

One worktree per active stream — each milestone (or independent fix) gets its own. Stay inside the active worktree; no edits outside, no reads from siblings. Merge only after VERIFY passes.

```bash
git checkout main
git branch feat/mNN-name
git worktree add ../usezombie-mNN-name feat/mNN-name
cd ../usezombie-mNN-name
```

After PR merge: `git worktree remove ../usezombie-mNN-name`.

---

## Memory Boundaries

- Process decisions belong in repo docs (specs, PR descriptions, changelogs).
- Do not rely on chat context when files can hold canonical state.

---

## Action-Triggered Guards

Guards fire regardless of lifecycle phase, pre-hoc not post-hoc. Each has a printable required-output block that must appear in the user-facing message before the gated edit. Pre-existing violations are not the agent's responsibility unless the task includes cleanup — but any new edit that introduces, extends, or perpetuates a violation does trigger the gate.

### Legacy-Design Consult Guard

**Definition — "legacy design":** any code path, env-var, table, route, or API that the surrounding milestone work is deprecating, that predates the current architectural direction, or that exists solely as a smoke-test / bootstrap / pre-migration shim. Signals:

- Code comments like `// legacy`, `// pre-M*`, `// bootstrap`, `// TODO remove`, `// temporary`.
- Runtime warn logs that announce themselves (`foo.bootstrap_env_var_used`, `legacy path`, `deprecated`).
- Env vars whose only consumer is a fallback branch (e.g. `ZOMBIED_ADMIN_API_KEY`).
- Principals / roles / config values that are "only used pre-signup" or "only used in dev."
- Schema columns / tables that spec work deletes everywhere except one stubborn caller.

**Trigger — you MUST stop and consult the user before any of these:**

- Adding a fix, fallback, or compensating code to make legacy design work with new architecture ("patching around it").
- Deciding to keep legacy design for "backward compat" when the spec/milestone's scope is explicitly pre-alpha or the user has no external consumers yet.
- Writing a defensive `orelse` / fail-open branch whose only reason to exist is that legacy design could produce a null/missing value.
- Authoring tests that exercise the legacy path — stop and ask whether the test (and path) should exist.
- Choosing between "patch the legacy path" vs "remove it entirely" — this is never your call to make silently.

**Required output (user-facing, before any edit):**

```
LEGACY CONSULT: <one-line description of the legacy design>
  Discovered in: <file:line or spec section>
  Options:
    (A) Remove it entirely — blast radius: <files/tests/callers>.
    (B) Patch around it — change: <what to add>, risk: <null/fallback/security>.
    (C) Keep as-is — justification: <why>.
  Recommendation: <A|B|C> because <reason>.
  WAITING FOR USER DECISION.
```

Block on the user's reply. If the user previously approved one class of legacy decisions this session, note that and proceed — but every *new* class of finding still triggers a consult.

**Escape hatch:** legacy findings unambiguously in-scope of the active spec's Dead Code Sweep or Out-of-Scope list skip the consult and follow the spec.

**Discovery capture:** every triggered consult is logged in the active spec's **Discovery** section, or filed as a new pending spec in `docs/v{N}/pending/` if pushed to follow-up. Never discard the finding.

### Schema Table Removal Guard

**Triggers** — before any of these, run `cat VERSION` and print the guard output:

- Creating, editing, or deleting any file under `schema/*.sql`.
- Editing `schema/embed.zig` (any `@embedFile` constant).
- Editing the canonical migration array in `src/cmd/common.zig`.
- Writing `DROP TABLE`, `ALTER TABLE`, or `SELECT 1;` into any SQL file.
- Accepting a spec dimension prescribing a "DROP migration", "ALTER migration", or "version marker".

**Pre-v2.0.0 (teardown-rebuild era):** to remove a table — (1) `rm schema/NNN_foo.sql`, (2) remove `@embedFile` from `schema/embed.zig`, (3) remove the entry from the migration array in `src/cmd/common.zig` and update length + index-based tests. **Forbidden:** `ALTER TABLE`, `DROP TABLE`, `SELECT 1;` markers, comment-only files, "keep file for slot numbering". Slot gaps are fine — DB is wiped on rebuild.

**v2.0.0+:** proper `ALTER`/`DROP` migrations in new numbered files.

**Spec conflicts:** spec violates the guard → **amend the spec first**.

**Required output format:**

```
SCHEMA GUARD: VERSION=<value from `cat VERSION`> (<2.0.0) → full teardown branch.
  Deleting: schema/008_harness_control_plane.sql
  Removing: schema.harness_control_plane_sql from embed.zig
  Removing: version 8 entry from canonicalMigrations()
```

Override syntax: `SCHEMA GUARD: SKIPPED per user override (reason: ...)`.

### File & Function Length Gate

**Caps:** file ≤ 350 lines · function ≤ 50 lines · method ≤ 70 lines.

**Triggers** — every Write/Edit that net-adds lines to a source file: `.zig`, `.js`, `.ts`, `.tsx`, `.jsx`, `.py`, `.rs`, `.go`, `.sh`, `.sql`, `.yaml`/`.toml` (when carrying code). When unsure, assume gated.

**Exemptions:**

- `vendor/`, `node_modules/`, `third_party/` (upstream code).
- `.md` files.
- Published API artifacts under `public/` (e.g. `public/openapi.json`, `public/openapi/paths/*.yaml`). Loose ≤ 400-line advisory on path YAMLs, by-eye in review.
- Repo-specific extensions in `docs/greptile-learnings/RULES.md`.

**Pre-edit check (mandatory):**

1. `wc -l <file>` — current count (0 for new files).
2. Net delta: `+added - removed`.
3. Projected: `current + delta`.
4. If projected > 350, **STOP**. Split first: extract a cohesive block to a sibling file using the repo's `<module>_<concern>.<ext>` convention (`zombie_list.js` beside `zombie.js`). Then apply the original edit.
5. Function sub-gate: project post-edit line count for any touched function. If > 50 (function) or > 70 (method), split into named helpers **before** writing.

**Required output format** (math runs every edit; print block only when projected ≥ 300 lines, or touched function within 10 of its cap):

```
LENGTH GATE: <file> currently N lines; adding Δ → N+Δ.
  File cap: 350. Headroom after: 350-(N+Δ).
  Function check: <fn_name> post-edit <F> lines (cap 50/70).
  Decision: proceed | split first.
```

**Splitting conventions:**

- File: name after the concern extracted, not parent + number. `zombie_list.js` not `zombie2.js`.
- Function: helper names describe the step, not the parent. `normalizeCursor()` not `helperA()`.

**Override syntax:** `LENGTH GATE: SKIPPED per user override (reason: ...)` in the chat message immediately preceding the edit.

### Milestone-ID Gate

Milestone IDs (`M{N}_{NNN}`), section refs (`§X.Y`), and dimension tokens (`T7`, `dim 5.8.15`) belong in specs, PR descriptions, and scratchpads — never in source code, since the codebase outlives any individual milestone and these references rot.

**Triggers — before saving any file matching:**

- `**/*.zig` · `**/*.sql` · `**/*.ts` · `**/*.tsx` · `**/*.js` · `**/*.jsx` · `**/*.py` · `**/*.rs` · `**/*.go` · `**/*.sh`
- Any config file (`*.toml`, `*.yaml`, `*.json`) outside `docs/`
- Test files (the `_test.` / `.test.` / `.spec.` naming doesn't exempt — tests are code).

**Exempt paths** (IDs allowed):

- `docs/` — specs, handoffs, changelogs.
- `**/*.md` outside `node_modules/`, `vendor/` — READMEs, ADRs, scratchpads.
- `CLAUDE.md`, `AGENTS.md` — this policy file.

**Pre-edit check (run before every Write/Edit):**

Grep your about-to-save content for these regexes:

```
M[0-9]+_[0-9]+          # M27_001, M11_006, M2_001
§[0-9]+(\.[0-9]+)+      # §3.8, §5.8.4, §0.5.1
\bT[0-9]+\b             # T7, T11 — test IDs from a spec
\bdim [0-9]+\.[0-9]+\b  # "dim 5.8.15"
```

If any match, **strip the reference before saving.** Rewrite to describe the code's purpose, not its spec lineage.

**Self-audit at end of turn (before declaring done):**

```bash
git diff --name-only HEAD | \
  grep -vE '(^docs/|\.md$)' | \
  xargs -r grep -nE 'M[0-9]+_[0-9]+|§[0-9]+(\.[0-9]+)+|\bT[0-9]+\b|\bdim [0-9]+\.[0-9]+\b' | \
  head
```

Non-empty output = violations introduced this turn. Fix before reporting done.

**Override syntax:** `MILESTONE ID ALLOWED per user override (reason: ...)` in the immediately-preceding comment line.

### Architecture Consult & Update Gate

A repository's `docs/ARCHITECHTURE.md` (or `docs/ARCHITECTURE.md`) is the canonical source for stream names, consumer groups, channel names, table cardinality, ownership, and end-to-end flows. Reinventing terms or asserting flow shapes from training data — instead of grounding in the doc — is the failure mode. Specs are *instances*; the architecture doc is the *constant*. When a spec and the architecture doc disagree, the architecture doc wins until the spec author and the architecture maintainer reconcile.

**Triggers** — before any of these, the gate fires and the printable block is mandatory in the user-facing message:

- Naming a stream / pub-sub channel / Redis key namespace / consumer group / queue / RPC method / Postgres schema / table.
- Asserting cardinality ("one row per X", "exactly one consumer per stream", "fleet-wide vs per-tenant").
- Describing a flow ("on crash → X reclaims via Y", "trigger source A lands on stream B with actor C").
- Answering a user question about how data flows between components.
- Proposing a change to any of the above as part of a spec or implementation.

**Required output format** (print before any architecture-affecting edit OR before answering an architecture-flow question in chat):

```
ARCH GATE: <topic>
  Grounded in: docs/ARCHITECHTURE.md §<section> lines <N-M>
  Canonical text: <one-line quote or precise paraphrase>
  Proposal / claim: <what is being asserted or about to change>
  Verdict: consistent | extends | conflicts
  If extends/conflicts: WAITING FOR USER DECISION before edit.
  Post-agreement: ARCHITECHTURE.md update lands in the SAME commit
                  as the implementation that depends on it.
```

If the file does not exist (greenfield repo or pre-architecture project), state `Grounded in: NO ARCHITECHTURE.md present — proposing initial decision; will land doc + code in same commit on user agreement` and proceed with extra care.

**EXECUTE-time corollary** (binding even outside this gate's printable block): an architecture decision agreed mid-task — naming, cardinality, ownership, new stream / channel / column — has its `docs/ARCHITECHTURE.md` edit ride in the SAME commit as the code that depends on it. Never split the doc edit into a follow-up. The PR that introduces a new stream without updating the architecture doc fails this gate retroactively at CHORE(close).

**CHORE(close) corollary**: every M-spec branch that touched flow-defining code must produce a non-empty `git diff origin/main..HEAD -- docs/ARCHITECHTURE.md`. If empty, either the branch genuinely changed nothing architectural (rare; document why in the PR Session Notes) or the doc edit is missing.

**Override syntax:** `ARCH GATE: SKIPPED per user override (reason: ...)` immediately preceding the edit. Do not use to dodge; use only when the work is genuinely architecture-neutral (e.g. a typo fix in user-facing error text).

### Pub Surface & Struct-Shape Gate

`docs/ZIG_RULES.md` mandates two Zig-file rules that drift silently if not surfaced:
1. **`pub` only when an external file imports the symbol** — default private; strip stale `pub`s when touching a file.
2. **File-as-struct shape for single-primary-type modules** — `const Foo = @This();` with fields immediately after, methods next, imports at file end. Multi-type modules (tagged unions + helpers, protocol with multiple shapes) keep conventional layout.

**Triggers** — before saving any of:

- A new `*.zig` file.
- An `Edit`/`Write` to a `*.zig` file that adds at least one new `pub` symbol — including new variants on an existing `pub` error/enum/union, since those expand the pub surface just as much as a new top-level declaration.
- ANY `Edit`/`Write` to an existing `*.zig` file whose primary purpose is exactly one struct — regardless of touch size. Per ZIG_RULES.md Single-Type-Module Pattern, single-primary-type files are required to use file-as-struct shape on every touch; the gate forces you to declare either "already file-as-struct" or "rearchitect in this diff."

**Pre-edit check (mandatory — run for EVERY Edit/Write to a `*.zig` file, not just ones you "think" add pubs):**

1. Will the new content contain any of the following patterns? Grep your about-to-save content:

   ```
   ^pub                  # new top-level pub declaration
   ^\s+pub fn            # new pub method on an existing struct
   ConnectionError\{[^}]*[A-Z][a-zA-Z]+,  # new variant on a pub error union
   = enum\s*\{[^}]*[A-Z][a-zA-Z]+,        # new variant on a pub enum
   ```

   If ANY pattern matches your new bytes (not the existing file content), the gate fires for this edit.

2. Count primary types in the file (struct/union/enum that the file is "about").
3. Choose layout: file-as-struct (count = 1) or conventional (count = 0 or > 1).
4. List every new `pub` symbol — top-level declarations AND variant additions on existing pub types — that the edit introduces.
5. For each, identify the external consumer (`grep -rn "<symbol>" src/ tests/ --include="*.zig"`) — file path + line, or `NONE`.
6. Strip `pub` from any with `NONE`.
7. Progressive cleanup on touch: `grep -n "^pub " <file>` and audit existing `pub`s in the same diff.

**Self-audit at end of turn** (before declaring done):

```bash
git diff -U0 HEAD -- '*.zig' | grep -E '^\+pub |^\+\s+pub fn |^\+\s+[A-Z][a-zA-Z]+,$' | head
```

Non-empty output = new pub surface introduced this turn. For each line, verify a PUB GATE block was printed in the user-facing message before the corresponding Edit/Write. Missing gate blocks are caught here, not at code review.

**Required output format** (print before the edit when the file is new OR when at least one new `pub` is being added):

```
PUB GATE: <file>
  Primary type count: <0|1|>1>
  Layout: <file-as-struct | conventional> (<one-line justification>)
  New `pub` symbols this edit:
    <symbol>: external consumer = <file:line> | NONE → strip
    <symbol>: external consumer = <file:line> | NONE → strip
  Existing `pub`s audited: <count> kept · <count> stripped
```

If no new `pub` symbols and the file is not new, the gate is a no-op — skip the printable block.

**Override syntax:** `PUB GATE: SKIPPED per user override (reason: ...)` immediately preceding the edit.

### Verification Gate

Fires before any user-facing message asserting the work is verified — "tests pass", "ready to merge", "shipping", "ready for review", "CHORE(close) ready", or any equivalent.

Package-scoped runners (`bun run test`, `vitest <file>`, `zig build test` without integration tier) are **not** verification — they skip cross-package lint, cross-compile, pg-drain, and integration. `make` targets are the canonical gates.

**Required before reporting done** (commands in the [VERIFY](#verify) section):

- `make lint` — always.
- `make test` — always (tier 1).
- `make test-integration` — when the diff touches HTTP handlers, schema, DB code, Redis code, or any `_integration_test.zig` file (tier 2). Use `make test-integration-db` / `make test-integration-redis` only when you need a focused subset.
- `make down && make up && make test-integration` — at least once per branch before declaring ship-ready (tier 3).
- Add-on gates (`make memleak`, `make bench`, cross-compile, `make check-pg-drain`) per the trigger table in `VERIFY`.

**Required output in the user-facing "done" message:**

```
Verified:
  make lint             ✓ clean
  make test             ✓ <N> passed, <M> skipped
  make test-integration ✓  (or "N/A — no handler/schema/redis changes")
  cross-compile         ✓  (when *.zig touched; omit otherwise)
```

**Override syntax** (only when a target is genuinely unrunnable — e.g. Docker missing for integration tests): `VERIFY GATE: <target> skipped per environment constraint (reason: ...)`. Call out the limitation in the done message — not as "tests pass".

---

## Specification Standards

**Canonical template:** [`docs/TEMPLATE.md`](./docs/TEMPLATE.md) in this dotfiles repo. Each project repo carries its own copy at the same path. Never look for `project_spec.md` or external docs.

### Terminology — forbidden substitutes

Hierarchy: **Prototype → Milestone → Workstream → Section → Dimension → Batch**. Applies to durable artifacts (specs, commits, PRs, handoffs, code comments) and user-facing prose. Conversational replies where the user used an industry term are exempt; the moment content lands in a file, project vocabulary wins.

| Use | Do NOT use |
|---|---|
| Prototype (v1.0.0) | Release, Version train, Program |
| Milestone (M{N}) | Sprint, Phase, Quarter, Release |
| Workstream (M{N}_{WS}) | Ticket, Task, Story, Issue, Subtask |
| Section (§3) | Phase, Step, Chapter, Stage |
| Dimension (3.4) | Acceptance criterion, AC, Subtask, Checkbox |
| Batch (B2) | Wave, Tranche, Iteration, Sprint |

Sequential slices inside a workstream are §1, §2, §3 — never "Phase 1/2". Slices large enough to stand alone become their own workstream + Batch designation.

### Spec lifecycle (directories)

```
docs/v{N}/
  pending/   ← created, not started
  active/    ← agent working (one worktree per spec)
  done/      ← all dimensions DONE, PR merged
```

### Triggers (presence of a spec is the trigger — don't wait for the user)

| Event | Action |
|---|---|
| New milestone request, plan-{eng,ceo}-review, attempt to create `TODO.md` | Copy `docs/TEMPLATE.md` → `docs/v{N}/pending/{naming}`. Fill ALL sections. `Status: PENDING`. Commit to main. **Never write `TODO.md`.** |
| Begin implementation OR branch carries spec changes in `pending/` | CHORE(open): move spec `pending/`→`active/`, set `Status: IN_PROGRESS` + `Branch:`, create worktree, commit on feature branch. **No code until these 4 steps committed.** |
| Every commit during implementation | Update spec — mark completed dimensions/sections `DONE`. Spec changes ride in the same commit as the code they verify. |
| All work complete, before PR | CHORE(close): see below. |
| Branch with spec in `active/` after any COMMIT | CHORE(close) is mandatory next action — do not stop, do not wait. Check `ls docs/v1/active/`. |

### File naming

```
docs/v{N}/{pending|active|done}/M{Milestone}_{Workstream}_P{Priority}_{CATEGORIES}_{DESCRIPTIVE_NAME}.md
```

- `Milestone`: `M{N}` — sortable by milestone first so `ls` groups by initiative.
- `Workstream`: zero-padded (`001`, `002`).
- `Priority`: P0 critical/blocking · P1 customer/operator-facing · P2 secondary/tooling · P3 deferrable.
- `CATEGORIES` (alphabetical, one or more): `UI` (Next.js dashboard) · `API` (Zig/Go handlers) · `CLI` (zombiectl, Node) · `OBS` (Grafana/metrics) · `SKILL` (YAML policy) · `INFRA` (Terraform/deploy).
- Example: `M52_001_P2_API_BUN_VENDOR_UTILITIES.md`.
- Legacy forms (`M{N}_{WKSTRM}_{NAME}.md` plain, or `P{Priority}_{CATEGORIES}_M{N}_{WS}_{NAME}.md` priority-first) exist under `docs/v1/` and `docs/v2/done/`; new specs use the milestone-first form above.

---

## Non-Trivial Definition

A task is **non-trivial** (full lifecycle) if it: touches >1 file · introduces a new abstraction · modifies a data model/schema · affects an external API/public interface · impacts a security boundary · requires migration/backfill · adds an infra dependency. Single-file typos and config-value tweaks are trivial.

## Deterministic Lifecycle

- **With spec:** `CHORE(open) → PLAN → EXECUTE → VERIFY → DOCUMENT → COMMIT → CHORE(close)`
- **Without spec** (bug fix, config change, refactor): `PLAN → EXECUTE → VERIFY → DOCUMENT → COMMIT`

Decision: if work creates or continues a spec under `docs/v*/active/` or `docs/v*/pending/`, run with CHORE bookends. Otherwise skip them.

### CHORE (open)

- Spec moved to correct directory; status set; committed.
- **Worktree created and CWD is inside it.** Never work directly in the main repo working tree:
  ```bash
  git checkout main
  git branch feat/mNN-name
  git worktree add ../usezombie-mNN-name feat/mNN-name
  cd ../usezombie-mNN-name
  ```
- Verify with `pwd` and `git worktree list`.
- No code changes yet.

### PLAN

Required outputs: one-paragraph goal · explicit assumptions · file/task impact list · verification plan (commands/tests) · read existing docs when behavior is unclear.

**Surface area checklist** — for each item, answer "yes (reason)" or "no (reason)":

- [ ] **OpenAPI spec update** — endpoints/shapes/error codes changed? List affected paths.
- [ ] **`zombiectl` CLI changes** — new subcommands/flags/output? PM must approve CLI surface changes.
- [ ] **User-facing docs** — `docs.usezombie.com` pages affected? List them.
- [ ] **Release notes** — version bump? Patch=fixes, minor=features, major=breaking post-v1.0. CHORE(close) updates `/Users/kishore/Projects/docs/changelog.mdx`.
- [ ] **Schema changes** — new SQL files ≤100 lines, single-concern; update `schema/embed.zig` + `src/cmd/common.zig` migration array; follow `docs/SCHEMA_CONVENTIONS.md`.
- [ ] **Schema teardown** — invoke the **Schema Table Removal Guard** above and print its output here, before any file edit. Guard re-fires at EXECUTE regardless.
- [ ] **Spec-vs-rules conflict check** — test the spec against AGENTS.md and `docs/greptile-learnings/RULES.md`. **Amend the spec first** if it conflicts. Common traps:
  - Spec prescribes DROP/ALTER or `SELECT 1;` while pre-v2.0 → violates Schema Guard.
  - Spec says "remove endpoints" without 410 while v2.0+ → violates **RULE EP4** (404 only allowed pre-v2.0).
  - Spec prescribes `conn.query()` without `.drain()` → violates zig-pg-drain.

**Spec is an instance, rules are the constant.** No file mutations during PLAN.

### EXECUTE

- **Spec's "Applicable Rules" section is canonical.** Read each listed rule file BEFORE writing code; re-check at VERIFY. Missing section → treat the standard set below as floor; surface omission to spec author.
- Read `docs/greptile-learnings/RULES.md` first (universal). Re-read when sub-task changes shape (new layer/language, resuming after break). Conflicts → state and ask, never silently skip.
- Zig changes → also read `docs/ZIG_RULES.md` (drain/dupe, cross-compile, TLS, memory, errdefer, ownership, sentinel, `pub` audit). Required by file-extension trigger even if spec omits it.
- HTTP handler / OpenAPI changes → read `docs/REST_API_DESIGN_GUIDELINES.md` first: Quick Checklist; §1–§5 (URL/method/body/response/error), §6 (OpenAPI editing), §7 (5-place route registration), §8 (`Hx` handler contract), §10 (pre-PR gates). Triggered by `src/http/handlers/**` or `public/openapi/**`.
- Schema-touching edits → re-print Schema Guard output (fires again at EXECUTE).
- Edit only files in approved scope; no opportunistic refactors. Stay inside the active worktree. Cross-repo writes require explicit user request (exception: symlinked-dotfiles carve-out — see Operational Defaults).

#### Spec → Code → Test contract

Specs with Interfaces and Test Specification sections must satisfy:

- Every Dimension maps to a test case. No test → not implemented.
- Every Interface appears in code with the exact spec signature. Signature change → update spec first.
- Every Acceptance Criterion is verifiable via a command. "Works correctly" is not a criterion; "`make test` passes" is.
- No code commits without tests that prove it works (use `/write-unit-test`).
- Zig changes → cross-compile mandatory: `zig build -Dtarget=x86_64-linux && zig build -Dtarget=aarch64-linux`.
- Every Error Contract row gets a negative test asserting the specified behavior.

#### Spec discipline

- **Golden-path before PLAN approval.** Walk the concrete end-to-end example including every lookup, data source, and secret-storage location. Any `[?]` blocks the spec.
- **DONE = called in production + tested.** Before marking a Dimension DONE: grep the production entry-point file for a call to the named symbol. No call → not DONE, regardless of unit tests.
- **Changelog claim challenge.** Before writing any `<Update>` block: ask "Would this be true if the test file vanished?" If the only evidence is a unit test of a library function (not a middleware/handler/CLI path), the claim is unearned — revise or delete.

### VERIFY

The [Verification Gate](#verification-gate) defines the required-output block; this section defines what to run and when.

#### Correctness tiers (do not skip a tier)

| Tier | Command | When |
|---|---|---|
| 1 | `make test` | Every iteration during EXECUTE and at start of VERIFY. |
| 2 | `make test-integration` | When diff touches `src/http/**`, `src/db/**`, `src/zombie/**`, `src/observability/**`, `*_integration_test.zig`, schema, or migrations — i.e. any production code reached by an `_integration_test.zig` file. Before COMMIT on those branches. |
| 3 | `make down && make up && make test-integration` | At least once per branch before declaring ship-ready. Mandatory when schema files change (pre-v2.0). Use whenever tier 2 is intermittent — fresh DB proves no state carry-over. |

`make test` is unit-only by definition; never substitutes for tier 2/3. If tier 2 passes but tier 3 fails, the bug is state pollution — fix isolation, don't ship until tier 3 is green.

#### Performance / leak gates (branch-level, before PR)

| Gate | Command | When |
|---|---|---|
| Leak | `make memleak` | Server lifecycle (`src/http/**`, `src/cmd/serve.zig`), allocator wiring, cross-thread heap ownership. |
| Bench (local) | `make bench` | Diff could affect request path or startup/shutdown. |
| Bench (dev) | `API_BENCH_URL=https://api-dev.usezombie.com/healthz make bench` | After branch deploys to dev. |

Bench env knobs (see `make/test-bench.mk`): `API_BENCH_METHOD`, `_DURATION_SEC`, `_CONCURRENCY`, `_TIMEOUT_MS`, `_MAX_ERROR_RATE`, `_MAX_P95_MS`, `_MAX_RSS_GROWTH_MB`.

**Memleak evidence rule:** before CHORE(close) reports green, paste the final `make memleak` result line into the PR description's Session Notes block OR cite the CI memleak job URL. Branches touching `src/http/**`, `src/cmd/serve.zig`, or allocator wiring MUST include the last 3 lines verbatim. No "I ran it, trust me."

#### Hygiene gates (always, before PR)

- `make lint` (full project, hard gate).
- `make check-pg-drain` whenever `*.zig` touched.
- Cross-compile `x86_64-linux` + `aarch64-linux` whenever `*.zig` touched.
- Cross-layer orphan sweep: every renamed/deleted symbol → 0 hits across schema/Zig/JS/tests/docs in non-historical files (RULE ORP).
- `gitleaks detect` before any commit including Zig.
- **350-line / 50-function-line gate** on every touched `.zig`/`.js` file (RULE FLL). Hard gate — split before DOCUMENT. Exempt: `.md`, `vendor/`, tests (`_test.`, `.test.`, `.spec.`, `tests/`). **FLL applies only to code files** — markdown specs, release notes, architecture docs, and changelogs are exempt; readability is the constraint, not line count. Never write grep gates that count markdown lines, and never mark FLL as an "Applicable Rule" on markdown-only workstreams.
  ```bash
  # file-length gate
  git diff --name-only origin/main \
    | grep -v -E '\.md$|^vendor/|_test\.|\.test\.|\.spec\.|/tests?/' \
    | xargs -I{} sh -c 'wc -l "{}"' \
    | awk '$1 > 350 { print "❌ " $2 ": " $1 " lines (limit 350)" }'
  ```

#### Other VERIFY outputs

- After any refactor, list newly dead code and confirm before removing:
  ```
  NEWLY UNREACHABLE AFTER THIS CHANGE:
  - [symbol/file]: [why now dead]
  → Remove these? Confirm before I proceed.
  ```
- **Greptile learning capture.** For each finding, ask "Could this recur elsewhere?" If yes, add a compact rule (Rule/Why/Tags/Ref) to `docs/greptile-learnings/RULES.md` in the same commit as the fix. Never defer the rule.

### DOCUMENT

Update user-visible docs for behavior/process changes. Update changelog only for user-visible changes. Record durable decisions in repo docs, not chat. No commit yet unless the user asked.

### COMMIT

Focused commits, clean message, no unrelated files. PR metadata via `gh`/`glab`. Mark completed Dimensions `DONE` in the spec. No amend unless requested. No destructive git ops. Outside auto mode, requires explicit user ask; inside auto mode with active-spec or start-instruction authorization, proceeds — see "Auto-mode autonomy" above for the full granted/gated split.

### CHORE (close)

Required when a spec is involved — runs immediately after the last COMMIT, before opening the PR. **Also runs when parking work midway** (mark completed Dimensions DONE, leave in-progress as IN_PROGRESS, set spec header accordingly).

#### Skill-driven review chain (mandatory order)

Run in order; each gate clears before the next:

1. **Before CHORE(close):** `/write-unit-test`. Audits test coverage of the diff against spec's Test Specification. Iterate until clean.
2. **After tests pass, before CHORE(close):** `/review`. Adversarial diff review against spec, architecture doc, REST guide (if HTTP), ZIG_RULES.md (if Zig), and spec's Failure Modes / Invariants. Address findings or document deferrals.
3. **After CHORE(close) commits + `gh pr create`:** `/review-pr`. Comments the PR via `gh pr review`. Address inline before requesting human review or merging.
4. **After every push (including post-PR-open and post-fix), greptile auto-reviews asynchronously.** `gh pr checks --watch` blocks on Actions and does NOT observe greptile — poll both independently. Workflow:
   - **Schedule a re-poll +180s after every push** (initial open AND every subsequent push). 180s ≈ greptile's analysis window; stays inside the 5-min cache window.
   - **Scheduling primitive:** Claude Code → `ScheduleWakeup(delaySeconds=180, reason="poll greptile on PR #N", prompt="re-poll greptile on PR #N (head <SHA>); fix findings if any, push, else merge")`. Codex CLI → `/schedule` or foreground `sleep 180`. Other runtimes → native scheduling or inline `sleep 180`.
   - **Fallback:** if no greptile reviewer at wakeup, re-schedule once. After 2 empty polls, proceed to merge.
   - Fetch via `gh api repos/<owner>/<repo>/pulls/<n>/reviews` + `/reviews/<id>/comments`. Filter for greptile reviewer. **Loop ALL review IDs, not just the first.**
   - For each P0/P1: check `docs/greptile-learnings/RULES.md` — if covered, append incident ref; if not, add new principle (Rule/Why/Tags/Ref).
   - Fix findings; re-run verification; reply to each thread with fix SHA via `gh api .../comments -X POST -F in_reply_to=<id>`; commit, push, **re-schedule +180s** on the new push.
   - Report findings/fixes/rules/reply IDs.

Skills are required gates, not optional. Skipping = CHORE(close) violation. Unavailable skill (MCP server down) → document in PR Session Notes: *"`/review` skipped — MCP unavailable <ts>; rerun before merge."*

Required outputs:

- All Dimensions/Sections marked `DONE` (or `IN_PROGRESS` if parked).
- Spec header `Status: DONE` (or `IN_PROGRESS`).
- Spec moved `docs/v*/active/` → `docs/v*/done/` (only if fully complete); commit on feature branch.
- **Release doc** — new `<Update>` block in `/Users/kishore/Projects/docs/changelog.mdx` (see format below). Never create `docs/v*/ship/*.md`.
- **PR description `## Session notes` block** — append to the PR body before opening: decisions taken, surfaced assumptions, dead ends, deferred follow-ups, and the `/write-unit-test` + `/review` skill outcomes (passed clean / iteration count / explicit skips). **Cross-session handoffs** (work parked midway for another session/agent to pick up) still use `docs/nostromo/HANDOFF_{MMM}_{DD}_{HH_MM}_M{N}_{WKSTRM}.md` — different artifact, narrower lifecycle.
- **Orphan sweep** completed (RULE ORP + RULE CHR) — 0 stale references.
- **Working tree clean** — `git status` reports `nothing to commit, working tree clean` BEFORE opening/updating the PR. Out-of-scope files: commit separately, gitignore, or delete. Never open a PR with a dirty tree.
- **Version sync** — branch touched `VERSION` → run `make sync-version`, include propagated edits (`build.zig.zon`, `zombiectl/package.json`, `zombiectl/src/cli.js`) in the CHORE(close) commit. Verify with `make check-version`. Skipping causes silent drift in `npm publish` and `zig build` outputs. No-op if VERSION untouched.

Gates before PR:
- `/write-unit-test` skill returned clean (or skip explicitly documented).
- `/review` skill returned clean (or all findings dispositioned in the diff).
- Spec is in `docs/v*/done/` in the branch diff (skip only if parked midway).
- `changelog.mdx` has a new `<Update>` block in the diff (skip only if internal-only refactor or parked).
- If `Status: DONE` but spec not in `done/` — do not open the PR.
- `make check-version` must pass. If the branch touched `VERSION`, the sync-version edits must be in the diff.

Gates after `gh pr create`:
- `/review-pr` invoked against the open PR. Comments addressed inline (push fixup commits or amend) BEFORE requesting human review or merging.
- Greptile workflow (step 4 above) — addressed before merge.

#### Release doc generation

Source of truth: `~/Projects/docs/changelog.mdx`. New `<Update>` block at the top (after `<Tip>`/`<Note>`). Labels are date-only (`MMM DD, YYYY`) — never a semver prefix; `VERSION` is decoupled from the changelog and propagated via `make sync-version`.

Block template + hard rules + version-bump matrix live in `~/Projects/dotfiles/skills/release-template.md`. Read that file at CHORE(close); copy the template, fill it in, drop the block into `changelog.mdx`. Do not paraphrase the template from memory — re-source it each release.

---

## Coding gotchas

- **Constant-time secret compare** — XOR over `@min(a.len, b.len)`; fold length mismatch into the result *after* the loop. Never short-circuit on `a.len == b.len` (leaks expected length via timing).
- **Typed enums over SQL `CHECK`** — drift silently from code; SQL can't reference Zig/JS constants. Use enums with `toSlice`/`fromSlice`.

(File/function length caps: see File & Function Length Gate. Zig test hygiene: `docs/ZIG_RULES.md`.)

## Skill routing (policy weight)

- Bug / "why is this broken" → `/investigate`. Never debug inline.
- "Ship it" / "push" / "create a PR" → `/ship`. Never raw `git push` / `gh pr create` outside the auto-mode carve-out.
- "Save my work" / "where was I" → `/context-save` + `/context-restore`.

## Tools & workflows

- **Make targets** — `dev | up | down | lint | test | build | _clean | push | qa | qa-smoke`. `make test` is unit-only; E2E in `qa`/`qa-smoke`. `make quality` banned (umbrella targets hide which gate failed). Missing target → one-line warning, then proceed.
- **Forge commands** — GitHub: `gh pr view|diff`, `gh run list|view <id>`. GitLab: `glab mr view|diff`, `glab ci status`, `glab pipeline view`. Red CI → inspect logs, fix, push, re-check.
- **Screenshots** — newest PNG from `~/Desktop` or `~/Downloads`; validate `sips -g pixelWidth -g pixelHeight`; `imageoptim` before commit.
- **Browser E2E** — Playwright CLI: `bun add -d @playwright/test && bunx playwright install --with-deps && bunx playwright test --reporter=line`.
- **Web → Markdown** — `curl -H "Accept: text/markdown" URL` first; fallback `curl -s URL | html2text`. Otherwise WebFetch (`format: markdown`).
