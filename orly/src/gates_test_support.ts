// Test harness for the gate suites (gates.test.ts, gates_spec.test.ts).
// Extracted per dispatch/write_any.md §Splitting conventions: inline test
// support is the first cut on an over-long file, because coverage instruments
// count harness code written inline as product.
import { copyFileSync, mkdirSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

import { isObject, RulesModel } from "./model";

const GIT = "git";
const QUIET = "-q";
const COMMIT = "commit";
const CONFIG = "config";
const ADD = "add";
const MESSAGE = "-m";
const PIPE_OUTPUT = "pipe";
const TRUE_COMMAND = "true";
const FIXTURE = "fixture";
const AUDITS_DIR = "audits";
const SPEC_GATE_SCRIPT = `${AUDITS_DIR}/spec-template.sh`;

export const ROOT = resolve(import.meta.dir, "../..");
export const SPEC_RELATIVE = "docs/v1/active/M99_001_P2_CLI_FIXTURE.md";
export const FIXTURE_PROFILE = { schema_version: 1, name: FIXTURE, packs: [], commands: { conform: [[TRUE_COMMAND]], "verify.unit": [[TRUE_COMMAND]] } };

const temporaryDirectories: string[] = [];
const GIT_SCOPE_VARIABLES = ["GIT_DIR", "GIT_INDEX_FILE", "GIT_WORK_TREE", "GIT_COMMON_DIR", "GIT_PREFIX", "GIT_OBJECT_DIRECTORY", "GIT_ALTERNATE_OBJECT_DIRECTORIES"];

// git exports GIT_DIR and GIT_INDEX_FILE to its hooks, and .githooks/pre-commit
// runs this suite through `make audit`. Inherited, they scope every git call at
// the dotfiles checkout: relative values resolve fixture-locally by luck in a
// plain repository and fatally in a linked worktree, whose .git is a file, so
// .git/index reads as "Not a directory". Bun does not propagate a deletion from
// process.env to a spawned child, so the scrubbed copy is passed explicitly.
const HERMETIC_ENVIRONMENT = hermeticEnvironment();

// Each suite registers this in its own afterEach — the array is module state
// shared by every importer, so a suite that skips it leaks its fixtures.
export function cleanupTemporaryDirectories(): void {
  for (const path of temporaryDirectories.splice(0)) rmSync(path, { recursive: true, force: true });
}

export function names(report: { results: Array<{ name: string }> }): string[] {
  return report.results.map((result) => result.name).sort();
}

export function orly(project: string, registry: string, ...args: string[]): { code: number; output: string } {
  const result = Bun.spawnSync(["bun", join(ROOT, "orly/src/cli.ts"), "--root", registry, ...args], { cwd: project, env: HERMETIC_ENVIRONMENT, stdout: PIPE_OUTPUT, stderr: PIPE_OUTPUT });
  return { code: result.exitCode, output: `${result.stdout.toString()}${result.stderr.toString()}` };
}

// A minimal registry root: the gate verbs read repositories + profiles and
// never render, so the full pack inventory is not needed.
export function fixtureRegistry(project: string): string {
  const root = temporaryDirectory();
  mkdirSync(join(root, "orly/profiles"), { recursive: true });
  Bun.write(join(root, "orly/registry.json"), JSON.stringify({ schema_version: 1, core_documents: [], packs: {}, rules: [] }));
  Bun.write(join(root, "orly/profiles/fixture.json"), JSON.stringify(FIXTURE_PROFILE));
  Bun.write(join(root, "orly/repositories.json"), JSON.stringify({ schema_version: 1, repositories: { fixture: { path: project, profile: FIXTURE } } }));
  return root;
}

export async function modelFor(
  project: string,
  surfaces?: { user: string[]; docs: string[] },
  extraCommands?: Record<string, string[][]>,
): Promise<RulesModel> {
  const source = await RulesModel.load(ROOT);
  const repositories = structuredClone(source.repositories);
  const profiles = structuredClone(source.profiles);
  if (!isObject(repositories.repositories)) throw new Error("repositories missing");
  repositories.repositories.fixture = { path: project, profile: FIXTURE };
  const fixture = structuredClone(FIXTURE_PROFILE) as Record<string, unknown>;
  if (surfaces) fixture.surfaces = surfaces;
  if (extraCommands) fixture.commands = { ...(fixture.commands as Record<string, unknown>), ...extraCommands };
  profiles.fixture = fixture;
  return new RulesModel(source.root, source.registry, profiles, repositories);
}

export function newRepository(): string {
  const project = temporaryDirectory();
  git(project, "init", QUIET);
  git(project, CONFIG, "user.email", "orly-tests@example.invalid");
  git(project, CONFIG, "user.name", "Orly Tests");
  Bun.write(join(project, "README.md"), "fixture\n");
  git(project, ADD, ".");
  git(project, COMMIT, QUIET, MESSAGE, "test: init");
  return project;
}

// A stream that already ran CHORE(close): the spec sits under done/ with
// Status: DONE and a Branch: header naming the branch, committed as the
// branch's first commit so ordering holds.
export function closedSpecRepository(branch: string, extraLines: string[] = []): string {
  const project = newRepository();
  git(project, "checkout", QUIET, "-b", branch);
  mkdirSync(join(project, "docs/v1/done"), { recursive: true });
  mkdirSync(join(project, AUDITS_DIR), { recursive: true });
  copyFileSync(join(ROOT, SPEC_GATE_SCRIPT), join(project, SPEC_GATE_SCRIPT));
  Bun.write(join(project, "docs/v1/done/M99_001_P2_CLI_FIXTURE.md"), specFixture("DONE", branch, extraLines));
  git(project, ADD, ".");
  git(project, COMMIT, QUIET, MESSAGE, "chore: close the fixture spec");
  return project;
}

export function newSpecRepository(): string {
  const project = newRepository();
  mkdirSync(join(project, "docs/v1/active"), { recursive: true });
  mkdirSync(join(project, AUDITS_DIR), { recursive: true });
  copyFileSync(join(ROOT, SPEC_GATE_SCRIPT), join(project, SPEC_GATE_SCRIPT));
  Bun.write(join(project, SPEC_RELATIVE), specFixture());
  git(project, ADD, ".");
  git(project, COMMIT, QUIET, MESSAGE, "test: add fixture spec");
  return project;
}

// A spec carrying every section audits/spec-template.sh requires, with all
// Dimensions already DONE so the gates' own criteria are what is under test.
export function specFixture(status = "IN_PROGRESS", branch?: string, extraLines: string[] = []): string {
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
    `**Status:** ${status}`,
    "**Priority:** P2 — fixture",
    ...(branch ? [`**Branch:** \`${branch}\``] : []),
    "**Test Baseline:** unit=0 integration=0",
    ...extraLines,
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

export function git(project: string, ...args: string[]): void {
  const result = Bun.spawnSync([GIT, ...args], { cwd: project, env: HERMETIC_ENVIRONMENT, stdout: "ignore", stderr: PIPE_OUTPUT });
  if (result.exitCode !== 0) throw new Error(result.stderr.toString());
}

export function gitOutput(project: string, ...args: string[]): string {
  const result = Bun.spawnSync([GIT, ...args], { cwd: project, env: HERMETIC_ENVIRONMENT, stdout: PIPE_OUTPUT, stderr: PIPE_OUTPUT });
  return result.exitCode === 0 ? result.stdout.toString().trim() : "";
}

export function temporaryDirectory(): string {
  const path = mkdtempSync(join(tmpdir(), "orly-gates-test-"));
  temporaryDirectories.push(path);
  return path;
}
