import { afterEach, describe, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, symlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

import { isObject, RulesModel } from "./model";
import {
  adoptRepository,
  doctorAgentHomes,
  doctorRepository,
  linkAgentHomes,
} from "./repository";
import { Renderer } from "./render";

const ROOT = resolve(import.meta.dir, "../..");
const temporaryDirectories: string[] = [];

afterEach(() => {
  for (const path of temporaryDirectories.splice(0)) rmSync(path, { recursive: true, force: true });
});

describe("repository adoption", () => {
  test("preserves existing repository instructions", async () => {
    const project = newRepository();
    const localRules = "# Local rules\n\nRun `make test`.\n";
    await Bun.write(join(project, "AGENTS.md"), localRules);
    commit(project, "test: add local rules");
    const model = await modelFor(project);

    await adoptRepository(model, "test");

    expect(await Bun.file(join(project, "AGENTS.project.md")).text()).toBe(localRules);
    expect(await Bun.file(join(project, "AGENTS.md")).text()).toContain(localRules.trim());
    expect(await doctorRepository(model, "test")).toEqual([]);
  });

  test("replaces a dotfiles-owned link without copying global rules", async () => {
    const project = newRepository();
    symlinkSync(join(ROOT, "AGENTS.md"), join(project, "AGENTS.md"));
    commit(project, "test: add legacy rules link");
    const model = await modelFor(project);

    await adoptRepository(model, "test");

    expect(await Bun.file(join(project, "AGENTS.project.md")).text()).toStartWith("# Repository instructions");
  });

  test("refuses external links before writing", async () => {
    const project = newRepository();
    const external = join(project, "../external-agents.md");
    await Bun.write(external, "external\n");
    symlinkSync(external, join(project, "AGENTS.md"));
    commit(project, "test: add external rules link");
    const model = await modelFor(project);

    expect(adoptRepository(model, "test")).rejects.toThrow("outside dotfiles");
    expect(await Bun.file(join(project, "AGENTS.project.md")).exists()).toBeFalse();
  });

  test("refuses dirty repositories before writing", async () => {
    const project = newRepository();
    await Bun.write(join(project, "unexpected.txt"), "dirty\n");
    const model = await modelFor(project);

    expect(adoptRepository(model, "test")).rejects.toThrow("must be clean");
    expect(await Bun.file(join(project, "AGENTS.project.md")).exists()).toBeFalse();
  });
});

describe("agent-home links", () => {
  test("retargets dotfiles-owned links and passes doctor", async () => {
    const root = temporaryDirectory();
    const generatedRoot = join(root, "generated/global");
    const model = await RulesModel.load(ROOT);
    await new Renderer(model).render("global", generatedRoot);
    const home = join(root, "home");
    mkdirSync(join(home, ".codex"), { recursive: true });
    symlinkSync(join(ROOT, "AGENTS.md"), join(home, ".codex/AGENTS.md"));

    await linkAgentHomes(model, home, join(generatedRoot, "AGENTS.md"));

    expect(await doctorAgentHomes(model, home, join(generatedRoot, "AGENTS.md"))).toEqual([]);
  });
});

async function modelFor(project: string): Promise<RulesModel> {
  const source = await RulesModel.load(ROOT);
  const repositories = structuredClone(source.repositories);
  if (!isObject(repositories.repositories)) throw new Error("repositories missing");
  repositories.repositories.test = { path: project, profile: "global" };
  return new RulesModel(source.root, source.registry, source.profiles, repositories);
}

function newRepository(): string {
  const project = temporaryDirectory();
  git(project, "init");
  git(project, "config", "user.email", "orly-tests@example.invalid");
  git(project, "config", "user.name", "Orly Tests");
  return project;
}

function commit(project: string, message: string): void {
  git(project, "add", ".");
  git(project, "commit", "-m", message);
}

function git(project: string, ...args: string[]): void {
  const result = Bun.spawnSync(["git", ...args], { cwd: project, stdout: "ignore", stderr: "pipe" });
  if (result.exitCode !== 0) throw new Error(result.stderr.toString());
}

function temporaryDirectory(): string {
  const path = mkdtempSync(join(tmpdir(), "orly-repository-test-"));
  temporaryDirectories.push(path);
  return path;
}
