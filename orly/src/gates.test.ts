import { afterEach, describe, expect, test } from "bun:test";
import { copyFileSync, mkdirSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

import { activeSpecPath, branchOverrides, recordOverride, runGate, runGates } from "./gates";
import { isObject, RulesModel } from "./model";

const ROOT = resolve(import.meta.dir, "../..");
const SPEC_RELATIVE = "docs/v1/active/M99_001_P2_CLI_FIXTURE.md";
const FIXTURE_PROFILE = { schema_version: 1, name: "fixture", packs: [], commands: { conform: [["true"]], "verify.unit": [["true"]] } };
const temporaryDirectories: string[] = [];
const GIT_SCOPE_VARIABLES = ["GIT_DIR", "GIT_INDEX_FILE", "GIT_WORK_TREE", "GIT_COMMON_DIR", "GIT_PREFIX", "GIT_OBJECT_DIRECTORY", "GIT_ALTERNATE_OBJECT_DIRECTORIES"];

// git exports GIT_DIR and GIT_INDEX_FILE to its hooks, and .githooks/pre-commit
// runs this suite through `make audit`. Inherited, they scope every git call at
// the dotfiles checkout: relative values resolve fixture-locally by luck in a
// plain repository and fatally in a linked worktree, whose .git is a file, so
// .git/index reads as "Not a directory". Bun does not propagate a deletion from
// process.env to a spawned child, so the scrubbed copy is passed explicitly.
const HERMETIC_ENVIRONMENT = hermeticEnvironment();

afterEach(() => {
  for (const path of temporaryDirectories.splice(0)) rmSync(path, { recursive: true, force: true });
});

describe("gate groups", () => {
  test("run in order and stop at the first red group", async () => {
    const project = newSpecRepository();
    const model = await modelFor(project);
    // Default branch: the work gate is red, so verify and pr never run.
    const reports = runGates(model, project);

    expect(reports.map((report) => report.gate)).toEqual(["work"]);
    expect(reports[0]?.ok).toBeFalse();
    expect(reports[0]?.results.find((result) => result.name === "git.branch")?.ok).toBeFalse();
  });

  test("each gate evaluates exactly its declared criteria", async () => {
    const project = newSpecRepository();
    const model = await modelFor(project);

    expect(names(runGate(model, project, "work"))).toEqual(["git.branch", "git.tree", "repo.profile"]);
    expect(names(runGate(model, project, "verify"))).toEqual(["cmd.conform", "cmd.verify.unit", "spec.dimensions"]);
    expect(names(runGate(model, project, "pr"))).toEqual([
      "docs.updated", "git.pushed", "git.tree", "spec.dimensions", "spec.gate", "spec.open-questions", "spec.product-clarity",
    ]);
  });

  test("gates never write: the tree is byte-identical after a run", async () => {
    const project = newSpecRepository();
    const model = await modelFor(project);
    const before = gitOutput(project, "status", "--porcelain=v1", "-uall");

    runGates(model, project);

    expect(gitOutput(project, "status", "--porcelain=v1", "-uall")).toBe(before);
  });
});

describe("spec discovery", () => {
  test("no spec tree: spec criteria skip and quality gates still run", async () => {
    const project = newRepository();
    const model = await modelFor(project);
    git(project, "checkout", "-q", "-b", "fix/adhoc");

    const verify = runGate(model, project, "verify");
    expect(verify.results.find((result) => result.name === "spec.dimensions")?.detail).toContain("no active spec");
    expect(verify.results.find((result) => result.name === "cmd.conform")?.ok).toBeTrue();
  });

  test("cache-kit style docs/v0.9.2/ layout is discovered", () => {
    const project = newRepository();
    mkdirSync(join(project, "docs/v0.9.2/active"), { recursive: true });
    Bun.write(join(project, "docs/v0.9.2/active/M05_001_P2_CLI_X.md"), specFixture());

    expect(activeSpecPath(project)).toContain("docs/v0.9.2/active");
  });

  test("two active specs are a hard error — one stream per worktree", () => {
    const project = newSpecRepository();
    mkdirSync(join(project, "docs/v2/active"), { recursive: true });
    Bun.write(join(project, "docs/v2/active/M02_001_P2_CLI_Y.md"), specFixture());

    expect(() => activeSpecPath(project)).toThrow("one stream per worktree");
  });
});

describe("repository resolution", () => {
  test("a linked worktree resolves to the profile its registered checkout declares", async () => {
    const project = newSpecRepository();
    const model = await modelFor(project);
    const worktree = join(temporaryDirectory(), "stream");
    git(project, "worktree", "add", "-q", "-b", "feat/stream", worktree);

    const profile = runGate(model, worktree, "work").results.find((result) => result.name === "repo.profile");

    expect(profile?.ok).toBeTrue();
    expect(profile?.detail).toBe("fixture -> fixture");
  });

  test("the profile's commands run in the worktree, not in the registered checkout", async () => {
    const project = newSpecRepository();
    const model = await modelFor(project, undefined, { conform: [["test", "-f", "stream-only.txt"]] });
    const worktree = join(temporaryDirectory(), "stream");
    git(project, "worktree", "add", "-q", "-b", "feat/stream", worktree);
    await Bun.write(join(worktree, "stream-only.txt"), "present only in the worktree\n");

    expect(runGate(model, worktree, "verify").results.find((result) => result.name === "cmd.conform")?.ok).toBeTrue();
    expect(runGate(model, project, "verify").results.find((result) => result.name === "cmd.conform")?.ok).toBeFalse();
  });

  test("an unrelated repository is still unregistered", async () => {
    const project = newSpecRepository();
    const model = await modelFor(project);
    const stranger = newRepository();

    const profile = runGate(model, stranger, "work").results.find((result) => result.name === "repo.profile");

    expect(profile?.ok).toBeFalse();
    expect(profile?.detail).toContain("not registered");
  });
});

describe("overrides", () => {
  test("a trailer satisfies its criterion as overridden, never green", async () => {
    const project = newSpecRepository();
    const model = await modelFor(project, { user: ["src/"], docs: ["docs/pages/"] });
    git(project, "checkout", "-q", "-b", "feat/fixture");
    await Bun.write(join(project, "src/handler.ts"), "export const HANDLER = 1;\n");
    git(project, "add", ".");
    git(project, "commit", "-q", "-m", "feat: change a user surface");

    expect(runGate(model, project, "pr").results.find((result) => result.name === "docs.updated")?.ok).toBeFalse();

    recordOverride(project, "docs.updated", "internal rename, no page exists");
    const overridden = runGate(model, project, "pr").results.find((result) => result.name === "docs.updated");
    expect(overridden?.ok).toBeTrue();
    expect(overridden?.detail).toStartWith("overridden (internal rename, no page exists)");
    expect(branchOverrides(project)).toEqual([{ criterion: "docs.updated", reason: "internal rename, no page exists" }]);
  });

  test("an empty reason is refused and no commit is created", () => {
    const project = newSpecRepository();
    git(project, "checkout", "-q", "-b", "feat/fixture");
    const head = gitOutput(project, "rev-parse", "HEAD");

    expect(() => recordOverride(project, "docs.updated", "  ")).toThrow("not a record");
    expect(gitOutput(project, "rev-parse", "HEAD")).toBe(head);
  });

  test("a malformed hand-written trailer is not an override", async () => {
    const project = newSpecRepository();
    const model = await modelFor(project, { user: ["src/"], docs: ["docs/pages/"] });
    git(project, "checkout", "-q", "-b", "feat/fixture");
    await Bun.write(join(project, "src/handler.ts"), "export const HANDLER = 1;\n");
    git(project, "add", ".");
    git(project, "commit", "-q", "-m", "feat: surface change\n\nOrly-Override: docs.updated no parentheses here");

    expect(branchOverrides(project)).toEqual([]);
    expect(runGate(model, project, "pr").results.find((result) => result.name === "docs.updated")?.ok).toBeFalse();
  });
});

describe("docs and tiered suites", () => {
  test("docs.updated goes green when a docs page changes on the branch", async () => {
    const project = newSpecRepository();
    const model = await modelFor(project, { user: ["src/"], docs: ["docs/pages/"] });
    git(project, "checkout", "-q", "-b", "feat/fixture");
    await Bun.write(join(project, "src/handler.ts"), "export const HANDLER = 1;\n");
    await Bun.write(join(project, "docs/pages/handler.md"), "# Handler\n");
    git(project, "add", ".");
    git(project, "commit", "-q", "-m", "feat: surface change with docs");

    expect(runGate(model, project, "pr").results.find((result) => result.name === "docs.updated")?.ok).toBeTrue();
  });

  test("slow suites run on code branches and skip on prose-only branches", async () => {
    const project = newSpecRepository();
    const model = await modelFor(project, { user: [], docs: [] }, { "verify.integration": [["false"]] });
    git(project, "checkout", "-q", "-b", "feat/fixture");
    await Bun.write(join(project, "notes.md"), "prose only\n");
    git(project, "add", ".");
    git(project, "commit", "-q", "-m", "docs: prose only");

    const skipped = runGate(model, project, "pr").results.find((result) => result.name === "cmd.verify.integration");
    expect(skipped?.ok).toBeTrue();
    expect(skipped?.detail).toContain("skipped — no code files");

    await Bun.write(join(project, "src/thing.ts"), "export const THING = 1;\n");
    git(project, "add", ".");
    git(project, "commit", "-q", "-m", "feat: add code");
    const ran = runGate(model, project, "pr").results.find((result) => result.name === "cmd.verify.integration");
    expect(ran?.ok).toBeFalse();
    expect(ran?.detail).toContain("false -> exit 1");
  });
});

describe("end to end", () => {
  test("gate walk through the real command-line entry", async () => {
    const project = newSpecRepository();
    const registry = fixtureRegistry(project);
    const upstream = temporaryDirectory();
    git(upstream, "init", "--bare", "-q");

    // Red on the default branch, at the work gate.
    let result = orly(project, registry, "gate");
    expect(result.code).toBe(1);
    expect(result.output).toContain("🔴 git.branch");

    git(project, "checkout", "-q", "-b", "feat/fixture");
    git(project, "remote", "add", "origin", upstream);
    git(project, "push", "-q", "-u", "origin", "feat/fixture");

    result = orly(project, registry, "gate");
    expect(`${result.output}`).toContain("PR boundary open");
    expect(result.code).toBe(0);
    expect(orly(project, registry, "gate", "pr").code).toBe(0);
    expect(orly(project, registry, "gate", "nope").code).not.toBe(0);
  });
});

function names(report: { results: Array<{ name: string }> }): string[] {
  return report.results.map((result) => result.name).sort();
}

function orly(project: string, registry: string, ...args: string[]): { code: number; output: string } {
  const result = Bun.spawnSync(["bun", join(ROOT, "orly/src/cli.ts"), "--root", registry, ...args], { cwd: project, stdout: "pipe", stderr: "pipe" });
  return { code: result.exitCode, output: `${result.stdout.toString()}${result.stderr.toString()}` };
}

// A minimal registry root: the gate verbs read repositories + profiles and
// never render, so the full pack inventory is not needed.
function fixtureRegistry(project: string): string {
  const root = temporaryDirectory();
  mkdirSync(join(root, "orly/profiles"), { recursive: true });
  Bun.write(join(root, "orly/registry.json"), JSON.stringify({ schema_version: 1, core_documents: [], packs: {}, rules: [] }));
  Bun.write(join(root, "orly/profiles/fixture.json"), JSON.stringify(FIXTURE_PROFILE));
  Bun.write(join(root, "orly/repositories.json"), JSON.stringify({ schema_version: 1, repositories: { fixture: { path: project, profile: "fixture" } } }));
  return root;
}

async function modelFor(
  project: string,
  surfaces?: { user: string[]; docs: string[] },
  extraCommands?: Record<string, string[][]>,
): Promise<RulesModel> {
  const source = await RulesModel.load(ROOT);
  const repositories = structuredClone(source.repositories);
  const profiles = structuredClone(source.profiles);
  if (!isObject(repositories.repositories)) throw new Error("repositories missing");
  repositories.repositories.fixture = { path: project, profile: "fixture" };
  const fixture = structuredClone(FIXTURE_PROFILE) as Record<string, unknown>;
  if (surfaces) fixture.surfaces = surfaces;
  if (extraCommands) fixture.commands = { ...(fixture.commands as Record<string, unknown>), ...extraCommands };
  profiles.fixture = fixture;
  return new RulesModel(source.root, source.registry, profiles, repositories);
}

function newRepository(): string {
  const project = temporaryDirectory();
  git(project, "init", "-q");
  git(project, "config", "user.email", "orly-tests@example.invalid");
  git(project, "config", "user.name", "Orly Tests");
  Bun.write(join(project, "README.md"), "fixture\n");
  git(project, "add", ".");
  git(project, "commit", "-q", "-m", "test: init");
  return project;
}

function newSpecRepository(): string {
  const project = newRepository();
  mkdirSync(join(project, "docs/v1/active"), { recursive: true });
  mkdirSync(join(project, "audits"), { recursive: true });
  copyFileSync(join(ROOT, "audits/spec-template.sh"), join(project, "audits/spec-template.sh"));
  Bun.write(join(project, SPEC_RELATIVE), specFixture());
  git(project, "add", ".");
  git(project, "commit", "-q", "-m", "test: add fixture spec");
  return project;
}

// A spec carrying every section audits/spec-template.sh requires, with all
// Dimensions already DONE so the gates' own criteria are what is under test.
function specFixture(): string {
  const sections = [
    "PR Intent & comprehension handshake",
    "Overview",
    "Implementing agent — read these first",
    "Files Changed (blast radius)",
    "Applicable Rules",
    "Applicable Gates",
    "Prior-Art / Reference Implementations",
    "Interfaces",
    "Failure Modes",
    "Invariants",
    "Metrics & Observability",
    "Test Specification (tiered)",
    "Acceptance Rubric",
    "Out of Scope",
    "Product Clarity (authoring record)",
    "Decomposition & alternatives",
    "Discovery (consult log)",
  ].map((heading) => `## ${heading}\n\nFixture content for ${heading}.\n`);
  return [
    "# M99_001: Fixture milestone",
    "",
    "**Status:** IN_PROGRESS",
    "**Priority:** P2 — fixture",
    "",
    "## Sections (implementation slices)",
    "",
    "### §1 — Fixture slice",
    "",
    "- **Dimension 1.1** — DONE — fixture behaviour → Test `fixture_test`",
    "",
    ...sections,
  ].join("\n");
}

function hermeticEnvironment(): Record<string, string | undefined> {
  const environment: Record<string, string | undefined> = { ...process.env };
  for (const name of GIT_SCOPE_VARIABLES) delete environment[name];
  return environment;
}

function git(project: string, ...args: string[]): void {
  const result = Bun.spawnSync(["git", ...args], { cwd: project, env: HERMETIC_ENVIRONMENT, stdout: "ignore", stderr: "pipe" });
  if (result.exitCode !== 0) throw new Error(result.stderr.toString());
}

function gitOutput(project: string, ...args: string[]): string {
  const result = Bun.spawnSync(["git", ...args], { cwd: project, env: HERMETIC_ENVIRONMENT, stdout: "pipe", stderr: "pipe" });
  return result.exitCode === 0 ? result.stdout.toString().trim() : "";
}

function temporaryDirectory(): string {
  const path = mkdtempSync(join(tmpdir(), "orly-gates-test-"));
  temporaryDirectories.push(path);
  return path;
}
