import { realpathSync } from "node:fs";
import { resolve } from "node:path";

import { isObject, JsonObject, objectValue, OrlyError, RulesModel } from "./model";
import { repositoryPath } from "./repository";
import { classifyBranch, SurfaceReport } from "./surfaces";

const PIPE_OUTPUT = "pipe";
const DEFAULT_BRANCHES = ["master", "main"];
const OPEN_QUESTION = "[?]";
const PRODUCT_CLARITY_HEADING = "## Product Clarity";
const DIMENSION_PREFIX = "- **Dimension ";
const DONE_MARKER = "DONE";
const SPEC_GATE_SCRIPT = "audits/spec-template.sh";
const CONFORM_COMMAND = "conform";
const VERIFY_PREFIX = "verify.";
const REPOSITORIES_LABEL = "repositories";
const NO_OUTPUT = "no output";
const UNREGISTERED = "repository is not registered in orly/repositories.json";
const NO_SPEC_SKIP = "skipped — no active spec (quality gates still apply)";
const REV_PARSE = "rev-parse";
const ABBREV_REF = "--abbrev-ref";

const SPEC_GATE = "spec.gate";
const SPEC_OPEN_QUESTIONS = "spec.open-questions";
const SPEC_PRODUCT_CLARITY = "spec.product-clarity";
const SPEC_DIMENSIONS = "spec.dimensions";
const GIT_BRANCH = "git.branch";
const GIT_TREE = "git.tree";
const GIT_PUSHED = "git.pushed";
const REPO_PROFILE = "repo.profile";
const DOCS_UPDATED = "docs.updated";

export type Verdict = { ok: boolean; detail: string };
export type CriterionResult = Verdict & { name: string };

export type CriterionContext = {
  root: string;
  // Absent when the repo has no active spec: spec criteria then skip-pass —
  // an ad-hoc bug fix meets quality gates, never a demand to write a spec.
  specPath?: string;
  specText?: string;
  model: RulesModel;
  acceptDirty: boolean;
  surfaces?: SurfaceReport;
};

export type Criterion = { name: string; evaluate: (context: CriterionContext) => CriterionResult };

// Every criterion is mechanical: it reads an exit code or a file, never a
// judgment. The anchor invariant promises the machine can PROVE the PR
// boundary, so anything unprovable stays prose and never lands here.
// work = is this branch workable · verify = does the work hold up ·
// pr = can this ship (whole-branch checks + the slow suites).
export function criteriaFor(gate: string, context: CriterionContext): Criterion[] {
  if (gate === "work") return [gitBranch(), gitTree(), repositoryProfile()];
  if (gate === "verify") return [specDimensions(), ...commandCriteria(context, FAST_TIER)];
  if (gate === "pr") {
    return [gitTree(), gitPushed(), specGate(), openQuestions(), productClarity(), specDimensions(), docsUpdated(), ...commandCriteria(context, SLOW_TIER)];
  }
  return [];
}

export function runCommand(root: string, command: string[]): Verdict {
  const result = Bun.spawnSync(command, { cwd: root, stdout: PIPE_OUTPUT, stderr: PIPE_OUTPUT });
  if (result.exitCode === 0) return { ok: true, detail: "exit 0" };
  const merged = `${result.stdout.toString()}\n${result.stderr.toString()}`;
  const lines = merged.split(/\r?\n/).map((line) => line.trim()).filter(Boolean);
  return { ok: false, detail: `exit ${result.exitCode}: ${lines[lines.length - 1] ?? NO_OUTPUT}` };
}

export function repositoryFor(model: RulesModel, root: string): string | undefined {
  const repositories = objectValue(model.repositories.repositories, REPOSITORIES_LABEL);
  const target = canonical(root);
  for (const name of Object.keys(repositories).sort()) {
    try {
      if (canonical(repositoryPath(model, name)) === target) return name;
    } catch {
      continue;
    }
  }
  return undefined;
}

// The name is written once and stamped onto the verdict, so a criterion can
// never report under a name that disagrees with the one it was registered as.
function criterion(name: string, evaluate: (context: CriterionContext) => Verdict): Criterion {
  return { name, evaluate: (context) => ({ name, ...evaluate(context) }) };
}

// Wrap a spec-reading criterion: no active spec → skip-pass with the reason
// printed, so quality gates still run on spec-less (ad-hoc) branches.
function specCriterion(name: string, evaluate: (context: CriterionContext) => Verdict): Criterion {
  return criterion(name, (context) => {
    if (!context.specText || !context.specPath) return { ok: true, detail: NO_SPEC_SKIP };
    return evaluate(context);
  });
}

function specGate(): Criterion {
  return specCriterion(SPEC_GATE, (context) => runCommand(context.root, ["bash", SPEC_GATE_SCRIPT, "--file", context.specPath ?? ""]));
}

function openQuestions(): Criterion {
  return specCriterion(SPEC_OPEN_QUESTIONS, (context) => {
    const hits = specLines(context).filter((line) => line.includes(OPEN_QUESTION));
    return { ok: hits.length === 0, detail: hits.length === 0 ? "no open questions" : `${hits.length} line(s) still carry ${OPEN_QUESTION}` };
  });
}

function productClarity(): Criterion {
  return specCriterion(SPEC_PRODUCT_CLARITY, (context) => {
    const present = specLines(context).some((line) => line.startsWith(PRODUCT_CLARITY_HEADING));
    return { ok: present, detail: present ? "section present" : `missing ${PRODUCT_CLARITY_HEADING}` };
  });
}

function specDimensions(): Criterion {
  return specCriterion(SPEC_DIMENSIONS, (context) => {
    const dimensions = specLines(context).filter((line) => line.trimStart().startsWith(DIMENSION_PREFIX));
    const open = dimensions.filter((line) => !line.includes(DONE_MARKER));
    return {
      ok: open.length === 0,
      detail: open.length === 0
        ? `${dimensions.length} dimension(s) marked ${DONE_MARKER}`
        : `${open.length} of ${dimensions.length} not ${DONE_MARKER}: ${dimensionLabels(open)}`,
    };
  });
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

const FAST_TIER = "fast";
const SLOW_TIER = "slow";
// The slow tier is a fixed name set, not a prefix rule: lint and version
// checks are verify.* too, and demoting them to skip-on-prose would be wrong.
const SLOW_COMMANDS = ["verify.integration", "verify.memory"];

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

function specLines(context: CriterionContext): string[] {
  return (context.specText ?? "").split(/\r?\n/);
}

function dimensionLabels(lines: string[]): string {
  return lines.map((line) => line.trim().slice(DIMENSION_PREFIX.length).split("*")[0]?.trim() ?? "?").join(", ");
}

function gitOutput(root: string, command: string[]): string {
  const result = Bun.spawnSync(["git", ...command], { cwd: root, stdout: PIPE_OUTPUT, stderr: PIPE_OUTPUT });
  return result.exitCode === 0 ? result.stdout.toString().trim() : "";
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
