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
import { readConfigSync, RepoConfig } from "./config";
import { classifyBranch, SurfaceReport } from "./surfaces";

export type { Criterion, CriterionContext, CriterionResult, Verdict };
export { runCommand };

const DEFAULT_BRANCHES = ["master", "main"];
const CONFORM_COMMAND = "conform";
const VERIFY_PREFIX = "verify.";
const REPOSITORIES_LABEL = "repositories";
const UNINSTALLED = "no .oracle/orly.json here — run `orly init` first";
const REV_PARSE = "rev-parse";
const ABBREV_REF = "--abbrev-ref";
const WORKTREE_LIST = ["worktree", "list", "--porcelain"];
const WORKTREE_PREFIX = "worktree ";

const GIT_BRANCH = "git.branch";
const GIT_TREE = "git.tree";
const GIT_PUSHED = "git.pushed";
const REPO_CONFIG = "repo.config";
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
  if (gate === "work") return [gitBranch(), gitTree(), repositoryConfig()];
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

function repositoryConfig(): Criterion {
  return criterion(REPO_CONFIG, (context) => {
    try {
      const config = readConfigSync(context.root);
      if (!config) return { ok: false, detail: UNINSTALLED };
      const commands = Object.keys(config.commands).length;
      return { ok: commands > 0, detail: commands > 0 ? `${commands} command(s) declared` : "no commands declared in .oracle/orly.json — add conform and verify.* so the gate can run them" };
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
  const config = resolvedConfig(context);
  if (!config) return tier === FAST_TIER ? [criterion(REPO_CONFIG, () => ({ ok: false, detail: UNINSTALLED }))] : [];
  const commands = config.commands;
  const selected = Object.keys(commands).filter((key) => tierOf(key) === tier).sort();
  return selected.map((key) => criterion(`cmd.${key}`, (inner) => {
    if (tier === SLOW_TIER && report(inner, config.surfaces).code.length === 0) {
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
    const config = resolvedConfig(context);
    if (!config?.surfaces) return { ok: true, detail: "no user surface declared in .oracle/orly.json" };
    const surfaces = report(context, config.surfaces);
    if (surfaces.userSurface.length === 0) return { ok: true, detail: "no user-surface files on this branch" };
    if (surfaces.docs.length > 0) return { ok: true, detail: `${surfaces.userSurface.length} user-surface file(s), ${surfaces.docs.length} docs file(s) updated` };
    return {
      ok: false,
      detail: `${surfaces.userSurface.length} user-surface file(s) changed (first: ${surfaces.userSurface[0] ?? ""}) with no docs change — update the docs page, or record: orly override ${DOCS_UPDATED} --reason <REASON>`,
    };
  });
}

// The branch is classified once per inspection and cached on the context.
function report(context: CriterionContext, surfaces: JsonObject | undefined): SurfaceReport {
  context.surfaces ??= classifyBranch(context.root, surfaces);
  return context.surfaces;
}

function resolvedConfig(context: CriterionContext): RepoConfig | undefined {
  try {
    return readConfigSync(context.root);
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

