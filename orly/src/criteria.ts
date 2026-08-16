import { realpathSync } from "node:fs";
import { resolve } from "node:path";

import {
  Criterion, CriterionContext, CriterionResult, criterion, gitOutput, runCommand, Verdict,
} from "./criteria_support";
import {
  openQuestions, productClarity, specBaseline, specDeferrals, specDimensions,
  specGate, specMoved, specOrdering,
} from "./criteria_spec";
import { isObject, JsonObject, objectValue, OrlyError, RulesModel } from "./model";
import { repositoryPath } from "./repository";
import { classifyBranch, SurfaceReport } from "./surfaces";

export type { Criterion, CriterionContext, CriterionResult, Verdict };
export { runCommand };

const DEFAULT_BRANCHES = ["master", "main"];
const CONFORM_COMMAND = "conform";
const VERIFY_PREFIX = "verify.";
const REPOSITORIES_LABEL = "repositories";
const UNREGISTERED = "repository is not registered in orly/repositories.json";
const REV_PARSE = "rev-parse";
const ABBREV_REF = "--abbrev-ref";
const WORKTREE_LIST = ["worktree", "list", "--porcelain"];
const WORKTREE_PREFIX = "worktree ";

const GIT_BRANCH = "git.branch";
const GIT_TREE = "git.tree";
const GIT_PUSHED = "git.pushed";
const REPO_PROFILE = "repo.profile";
const DOCS_UPDATED = "docs.updated";

const FAST_TIER = "fast";
const SLOW_TIER = "slow";
// The slow tier is a fixed name set, not a prefix rule: lint and version
// checks are verify.* too, and demoting them to skip-on-prose would be wrong.
const SLOW_COMMANDS = ["verify.integration", "verify.memory"];

// Every criterion is mechanical: it reads an exit code or a file, never a
// judgment. The anchor invariant promises the machine can PROVE the PR
// boundary, so anything unprovable stays prose and never lands here.
// work = is this branch workable · verify = does the work hold up ·
// pr = can this ship (whole-branch checks + the slow suites).
export function criteriaFor(gate: string, context: CriterionContext): Criterion[] {
  if (gate === "work") return [gitBranch(), gitTree(), repositoryProfile()];
  if (gate === "verify") return [specDimensions(), ...commandCriteria(context, FAST_TIER)];
  if (gate === "pr") {
    return [
      gitTree(), gitPushed(), specGate(), openQuestions(), productClarity(), specDimensions(),
      specMoved(), specBaseline(), specOrdering(), specDeferrals(),
      docsUpdated(), ...commandCriteria(context, SLOW_TIER),
    ];
  }
  return [];
}

// Identity is the set of checkouts sharing one object store, never the path
// alone: the operating model puts one stream per worktree, so a registry that
// matched paths exactly would resolve only the stream that happens to occupy
// the registered checkout and call every sibling worktree unregistered.
// Resolution is the only thing widened — context.root stays the worktree, so
// the profile's commands still run in the stream's own tree.
export function repositoryFor(model: RulesModel, root: string): string | undefined {
  const repositories = objectValue(model.repositories.repositories, REPOSITORIES_LABEL);
  const checkouts = new Set([canonical(root), ...attachedCheckouts(root)]);
  for (const name of Object.keys(repositories).sort()) {
    try {
      if (checkouts.has(canonical(repositoryPath(model, name)))) return name;
    } catch {
      continue;
    }
  }
  return undefined;
}

function gitBranch(): Criterion {
  return criterion(GIT_BRANCH, (context) => {
    const branch = gitOutput(context.root, [REV_PARSE, ABBREV_REF, "HEAD"]);
    const ok = branch.length > 0 && !DEFAULT_BRANCHES.includes(branch);
    return { ok, detail: ok ? `on ${branch}` : `refusing to work on the default branch: ${branch || "unknown"}` };
  });
}

function gitTree(): Criterion {
  return criterion(GIT_TREE, (context) => {
    // The active spec is excluded while work is in flight: Dimensions get
    // marked DONE as the agent goes, and the tree check must not block on that
    // bookkeeping. Committing the spec stays a CHORE(close) obligation.
    const dirty = gitOutput(context.root, ["status", "--porcelain=v1", "-uall"])
      .split(/\r?\n/)
      .filter(Boolean)
      .filter((line) => !context.specPath || !line.includes(context.specPath));
    if (dirty.length === 0) return { ok: true, detail: "clean (active spec excluded)" };
    if (context.acceptDirty) return { ok: true, detail: `${dirty.length} dirty path(s) accepted` };
    return { ok: false, detail: `${dirty.length} uncommitted path(s), first: ${dirty[0] ?? ""}` };
  });
}

function gitPushed(): Criterion {
  return criterion(GIT_PUSHED, (context) => {
    const upstream = gitOutput(context.root, [REV_PARSE, ABBREV_REF, "--symbolic-full-name", "@{upstream}"]);
    if (upstream.length === 0) return { ok: false, detail: "branch has no upstream; push it first" };
    const ahead = gitOutput(context.root, ["rev-list", "--count", "@{upstream}..HEAD"]);
    const ok = ahead === "0";
    return { ok, detail: ok ? `in sync with ${upstream}` : `${ahead} commit(s) not pushed to ${upstream}` };
  });
}

function repositoryProfile(): Criterion {
  return criterion(REPO_PROFILE, (context) => {
    const name = repositoryFor(context.model, context.root);
    if (!name) return { ok: false, detail: UNREGISTERED };
    try {
      return { ok: true, detail: `${name} -> ${profileName(context.model, name)}` };
    } catch (error) {
      return { ok: false, detail: error instanceof Error ? error.message : String(error) };
    }
  });
}

// Model C: the repository's declared command surface. Orly owns policy and
// invokes these; the repository owns what they actually do. Fast tier =
// conform + verify.unit. Slow tier = every other verify.* (integration,
// memleak); those auto-pass with a printed skip when the branch carries no
// code, so a prose-only branch never pays for the slow suites.
function commandCriteria(context: CriterionContext, tier: string): Criterion[] {
  const profile = resolvedProfile(context);
  if (!profile) return tier === FAST_TIER ? [criterion(REPO_PROFILE, () => ({ ok: false, detail: UNREGISTERED }))] : [];
  const commands = objectValue(profile.commands, "profile commands");
  const selected = Object.keys(commands).filter((key) => tierOf(key) === tier).sort();
  return selected.map((key) => criterion(`cmd.${key}`, (inner) => {
    if (tier === SLOW_TIER && report(inner, profile).code.length === 0) {
      return { ok: true, detail: "skipped — no code files on this branch" };
    }
    return runInvocations(inner.root, commands[key]);
  }));
}

function tierOf(key: string): string {
  if (SLOW_COMMANDS.includes(key)) return SLOW_TIER;
  if (key === CONFORM_COMMAND || key.startsWith(VERIFY_PREFIX)) return FAST_TIER;
  return "";
}

function docsUpdated(): Criterion {
  return criterion(DOCS_UPDATED, (context) => {
    const profile = resolvedProfile(context);
    if (!profile) return { ok: true, detail: "no registered profile — no declared user surface" };
    const surfaces = report(context, profile);
    if (surfaces.userSurface.length === 0) return { ok: true, detail: "no user-surface files on this branch" };
    if (surfaces.docs.length > 0) return { ok: true, detail: `${surfaces.userSurface.length} user-surface file(s), ${surfaces.docs.length} docs file(s) updated` };
    return {
      ok: false,
      detail: `${surfaces.userSurface.length} user-surface file(s) changed (first: ${surfaces.userSurface[0] ?? ""}) with no docs change — update the docs page, or record: orly override ${DOCS_UPDATED} --reason <REASON>`,
    };
  });
}

// The branch is classified once per inspection and cached on the context.
function report(context: CriterionContext, profile: JsonObject): SurfaceReport {
  context.surfaces ??= classifyBranch(context.root, profile);
  return context.surfaces;
}

function resolvedProfile(context: CriterionContext): JsonObject | undefined {
  const name = repositoryFor(context.model, context.root);
  if (!name) return undefined;
  try {
    return context.model.profile(profileName(context.model, name));
  } catch {
    return undefined;
  }
}

function runInvocations(root: string, invocations: unknown): Verdict {
  if (!Array.isArray(invocations) || invocations.length === 0) return { ok: false, detail: "command group is empty" };
  for (const invocation of invocations) {
    if (!Array.isArray(invocation) || invocation.length === 0) return { ok: false, detail: "command invocation is empty" };
    const argv = invocation.map((argument) => String(argument));
    const result = runCommand(root, argv);
    if (!result.ok) return { ok: false, detail: `${argv.join(" ")} -> ${result.detail}` };
  }
  return { ok: true, detail: `${invocations.length} invocation(s) exit 0` };
}

function profileName(model: RulesModel, repository: string): string {
  const value = model.repository(repository).profile;
  if (typeof value !== "string" || value.length === 0) throw new OrlyError(`repository ${repository} profile must be a string`);
  if (!isObject(model.profiles[value])) throw new OrlyError(`repository ${repository} selects unknown profile: ${value}`);
  return value;
}

// Every checkout git attaches to this repository — the main worktree first,
// then each linked one. Asking git beats deriving the main checkout from the
// common Git directory, which would assume the <toplevel>/.git layout and
// break on bare mains and separate Git directories. Empty outside a
// repository, leaving the caller comparing paths alone as it did before.
function attachedCheckouts(root: string): string[] {
  return gitOutput(root, WORKTREE_LIST)
    .split(/\r?\n/)
    .filter((line) => line.startsWith(WORKTREE_PREFIX))
    .map((line) => canonical(line.slice(WORKTREE_PREFIX.length).trim()));
}

// Compare canonical paths: git reports the symlink-resolved root while a
// registered path may be written through a link, and this workspace is
// symlink-heavy. Falling back to resolve() keeps a missing path comparable.
function canonical(path: string): string {
  try {
    return realpathSync(path);
  } catch {
    return resolve(path);
  }
}
