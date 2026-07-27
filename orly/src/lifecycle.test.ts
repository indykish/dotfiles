import { afterEach, describe, expect, test } from "bun:test";
import { copyFileSync, mkdirSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

import {
  activeOverrides,
  advance,
  appendTransition,
  applyStatus,
  currentState,
  formatTimestamp,
  inspect,
  parseTransitions,
  record,
  TransitionRow,
} from "./lifecycle";
import { isObject, RulesModel } from "./model";

const ROOT = resolve(import.meta.dir, "../..");
const SPEC_RELATIVE = "docs/v1/active/M99_001_P2_CLI_FIXTURE.md";
const NOW = new Date(2026, 6, 27, 16, 35);
const FIXTURE_PROFILE = { schema_version: 1, name: "fixture", packs: [], commands: { conform: [["true"]], "verify.unit": [["true"]] } };
const temporaryDirectories: string[] = [];

afterEach(() => {
  for (const path of temporaryDirectories.splice(0)) rmSync(path, { recursive: true, force: true });
});

describe("transition log", () => {
  test("append-only: rows accumulate and the tail is the state", () => {
    let text = specFixture();
    expect(currentState(parseTransitions(text))).toBe("PENDING");

    text = appendTransition(text, row("PENDING", "PLANNED", "green"));
    text = appendTransition(text, row("PLANNED", "EXECUTING", "green"));

    const rows = parseTransitions(text);
    expect(rows).toHaveLength(2);
    expect(rows[0]?.to).toBe("PLANNED");
    expect(currentState(rows)).toBe("EXECUTING");
  });

  test("rejects a corrupted row instead of inventing a state", () => {
    const text = specFixture().replace("| Timestamp | From → To | Actor | Verdict |\n|---|---|---|---|", "| Timestamp | From → To | Actor | Verdict |\n|---|---|---|---|\n| Jul 27, 2026: 01:00 PM | PENDING → NOWHERE | agent | green |");

    expect(() => parseTransitions(text)).toThrow("unreadable transition row");
  });

  test("Status is derived from the state, never the other way round", () => {
    expect(applyStatus(specFixture(), "EXECUTING")).toContain("**Status:** IN_PROGRESS");
    expect(applyStatus(specFixture(), "DONE")).toContain("**Status:** DONE");
    expect(applyStatus(specFixture(), "PENDING")).toContain("**Status:** PENDING");
  });

  test("overrides apply only to the state they were recorded in", () => {
    let text = specFixture();
    text = appendTransition(text, row("PENDING", "PLANNED", "green"));
    text = appendTransition(text, row("PLANNED", "PLANNED", "OVERRIDE(spec.gate): vendor format"));
    expect(activeOverrides(parseTransitions(text))).toEqual(["spec.gate"]);

    text = appendTransition(text, row("PLANNED", "EXECUTING", "green"));
    expect(activeOverrides(parseTransitions(text))).toEqual([]);
  });

  test("timestamps use the house prose format", () => {
    expect(formatTimestamp(NOW)).toBe("Jul 27, 2026: 04:35 PM");
    expect(formatTimestamp(new Date(2026, 0, 1, 0, 5))).toBe("Jan 01, 2026: 12:05 AM");
  });
});

describe("advance", () => {
  test("halts on a red criterion and writes nothing", async () => {
    const project = newSpecRepository();
    const model = await modelFor(project);

    // Default branch + dirty tree: PLANNED -> EXECUTING must refuse.
    await record(project, NOW, "agent", "PLANNED", "bootstrap");
    await Bun.write(join(project, "dirty.txt"), "uncommitted\n");
    const before = await Bun.file(join(project, SPEC_RELATIVE)).text();
    const { view, advanced } = await advance(model, project, NOW);

    expect(advanced).toBeFalse();
    expect(view.target).toBe("EXECUTING");
    expect(view.results.filter((result) => !result.ok).map((result) => result.name).sort()).toEqual(["git.branch", "git.tree"]);
    expect(await Bun.file(join(project, SPEC_RELATIVE)).text()).toBe(before);
  });

  test("records an override as an override, never as green", async () => {
    const project = newSpecRepository();
    const model = await modelFor(project);
    await record(project, NOW, "agent", "PLANNED", "bootstrap");
    git(project, "checkout", "-q", "-b", "feat/fixture");
    await Bun.write(join(project, "dirty.txt"), "uncommitted\n");

    await record(project, NOW, "indy", undefined, "OVERRIDE(git.tree): scratch file, deliberate");
    const { view, advanced } = await advance(model, project, NOW);

    expect(advanced).toBeTrue();
    const tree = view.results.find((result) => result.name === "git.tree");
    expect(tree?.ok).toBeTrue();
    expect(tree?.detail).toStartWith("overridden — ");
    const text = await Bun.file(join(project, SPEC_RELATIVE)).text();
    expect(text).toContain("OVERRIDE(git.tree): scratch file, deliberate");
    expect(text).toContain("green (1 override(s): git.tree)");
  });

  test("status reports red criteria without mutating the spec", async () => {
    const project = newSpecRepository();
    const model = await modelFor(project);
    await record(project, NOW, "agent", "PLANNED", "bootstrap");
    const before = await Bun.file(join(project, SPEC_RELATIVE)).text();

    const view = await inspect(model, project);

    expect(view.state).toBe("PLANNED");
    expect(view.results.some((result) => !result.ok)).toBeTrue();
    expect(await Bun.file(join(project, SPEC_RELATIVE)).text()).toBe(before);
  });

  test("each transition evaluates exactly its declared criteria", async () => {
    const project = newSpecRepository();
    const model = await modelFor(project);

    expect(names(await inspect(model, project, false, "PLANNED"))).toEqual(["spec.gate", "spec.open-questions", "spec.product-clarity"]);
    expect(names(await inspect(model, project, false, "EXECUTING"))).toEqual(["git.branch", "git.tree", "repo.profile"]);
    expect(names(await inspect(model, project, false, "VERIFIED"))).toEqual(["cmd.conform", "cmd.verify.unit", "spec.dimensions"]);
    expect(names(await inspect(model, project, false, "PR_READY"))).toEqual(["docs.updated", "git.pushed", "git.tree", "spec.dimensions", "spec.gate"]);
  });

  test("docs.updated blocks a user-surface change with no docs change", async () => {
    const project = newSpecRepository();
    const model = await modelFor(project, { user: ["src/"], docs: ["docs/pages/"] });
    git(project, "checkout", "-q", "-b", "feat/fixture");
    await Bun.write(join(project, "src/handler.ts"), "export const HANDLER = 1;\n");
    git(project, "add", ".");
    git(project, "commit", "-q", "-m", "test: change a user surface");

    const blocked = await inspect(model, project, false, "PR_READY");
    const docs = blocked.results.find((result) => result.name === "docs.updated");
    expect(docs?.ok).toBeFalse();
    expect(docs?.detail).toContain("orly override docs.updated");

    await Bun.write(join(project, "docs/pages/handler.md"), "# Handler\n");
    git(project, "add", ".");
    git(project, "commit", "-q", "-m", "docs: document the handler");
    const green = await inspect(model, project, false, "PR_READY");
    expect(green.results.find((result) => result.name === "docs.updated")?.ok).toBeTrue();
  });

  test("slow suites run on code branches and skip on prose-only branches", async () => {
    const project = newSpecRepository();
    const model = await modelFor(project, { user: [], docs: [] }, { "verify.integration": [["false"]] });
    git(project, "checkout", "-q", "-b", "feat/fixture");
    await Bun.write(join(project, "notes.md"), "prose only\n");
    git(project, "add", ".");
    git(project, "commit", "-q", "-m", "docs: prose only");

    const prose = await inspect(model, project, false, "PR_READY");
    const skipped = prose.results.find((result) => result.name === "cmd.verify.integration");
    expect(skipped?.ok).toBeTrue();
    expect(skipped?.detail).toContain("skipped — no code files");

    await Bun.write(join(project, "src/thing.ts"), "export const THING = 1;\n");
    git(project, "add", ".");
    git(project, "commit", "-q", "-m", "feat: add code");
    const code = await inspect(model, project, false, "PR_READY");
    const ran = code.results.find((result) => result.name === "cmd.verify.integration");
    expect(ran?.ok).toBeFalse();
    expect(ran?.detail).toContain("false -> exit 1");
  });

  test("reports no machine transition beyond PR_READY", async () => {
    const project = newSpecRepository();
    const model = await modelFor(project);
    await record(project, NOW, "agent", "PR_READY", "bootstrap");

    const { view, advanced } = await advance(model, project, NOW);

    expect(advanced).toBeFalse();
    expect(view.target).toBeUndefined();
  });
});

describe("escape hatches", () => {
  test("park and reset append rows and move the state", async () => {
    const project = newSpecRepository();
    await record(project, NOW, "agent", "EXECUTING", "bootstrap");

    const parked = await record(project, NOW, "indy", "PARKED", "PARK: waiting on upstream");
    expect(parked.from).toBe("EXECUTING");
    expect(currentState(parseTransitions(await Bun.file(join(project, SPEC_RELATIVE)).text()))).toBe("PARKED");

    const reset = await record(project, NOW, "indy", "PLANNED", "RESET: replanning the split");
    expect(reset.to).toBe("PLANNED");
    expect(parseTransitions(await Bun.file(join(project, SPEC_RELATIVE)).text())).toHaveLength(3);
  });
});

describe("end to end", () => {
  test("walks PENDING to PR_READY through the real command-line entry", async () => {
    const project = newSpecRepository();
    const registry = fixtureRegistry(project);
    const upstream = temporaryDirectory();
    git(upstream, "init", "--bare", "-q");
    git(project, "checkout", "-q", "-b", "feat/fixture");
    git(project, "remote", "add", "origin", upstream);
    git(project, "push", "-q", "-u", "origin", "feat/fixture");

    for (const expected of ["PENDING → PLANNED", "PLANNED → EXECUTING", "EXECUTING → VERIFIED", "VERIFIED → PR_READY"]) {
      const result = orly(project, registry, "next");
      expect(`${expected} :: ${result.output}`).toContain(`🟢 ${expected}`);
    }

    const rows = parseTransitions(await Bun.file(join(project, SPEC_RELATIVE)).text());
    expect(rows).toHaveLength(4);
    expect(currentState(rows)).toBe("PR_READY");
    expect(orly(project, registry, "check", "PR_READY").code).toBe(0);
    expect(orly(project, registry, "check", "NOPE").code).toBe(1);
  });
});

function names(view: { results: Array<{ name: string }> }): string[] {
  return view.results.map((result) => result.name).sort();
}

function row(from: string, to: string, verdict: string): TransitionRow {
  return { timestamp: formatTimestamp(NOW), from: from as TransitionRow["from"], to: to as TransitionRow["to"], actor: "agent", verdict };
}

function orly(project: string, registry: string, ...args: string[]): { code: number; output: string } {
  const result = Bun.spawnSync(["bun", join(ROOT, "orly/src/cli.ts"), "--root", registry, ...args], { cwd: project, stdout: "pipe", stderr: "pipe" });
  return { code: result.exitCode, output: `${result.stdout.toString()}${result.stderr.toString()}` };
}

// A minimal registry root: the lifecycle verbs read repositories + profiles and
// never render, so the full pack inventory is not needed to drive the engine.
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

function newSpecRepository(): string {
  const project = temporaryDirectory();
  git(project, "init", "-q");
  git(project, "config", "user.email", "orly-tests@example.invalid");
  git(project, "config", "user.name", "Orly Tests");
  mkdirSync(join(project, "docs/v1/active"), { recursive: true });
  mkdirSync(join(project, "audits"), { recursive: true });
  copyFileSync(join(ROOT, "audits/spec-template.sh"), join(project, "audits/spec-template.sh"));
  Bun.write(join(project, SPEC_RELATIVE), specFixture());
  git(project, "add", ".");
  git(project, "commit", "-q", "-m", "test: add fixture spec");
  return project;
}

// A spec carrying every section audits/spec-template.sh requires, with all
// Dimensions already DONE so the engine's own criteria are what is under test.
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
    "**Status:** PENDING",
    "**Priority:** P2 — fixture",
    "",
    "## Sections (implementation slices)",
    "",
    "### §1 — Fixture slice",
    "",
    "- **Dimension 1.1** — DONE — fixture behaviour → Test `fixture_test`",
    "",
    "## Transitions",
    "",
    "| Timestamp | From → To | Actor | Verdict |",
    "|---|---|---|---|",
    "",
    ...sections,
  ].join("\n");
}

function git(project: string, ...args: string[]): void {
  const result = Bun.spawnSync(["git", ...args], { cwd: project, stdout: "ignore", stderr: "pipe" });
  if (result.exitCode !== 0) throw new Error(result.stderr.toString());
}

function temporaryDirectory(): string {
  const path = mkdtempSync(join(tmpdir(), "orly-lifecycle-test-"));
  temporaryDirectories.push(path);
  return path;
}
