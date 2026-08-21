import { afterEach, describe, expect, test } from "bun:test";
import { join } from "node:path";

import { branchOverrides, recordOverride, runGate, runGates } from "./gates";
import {
  cleanupTemporaryDirectories, fixtureRegistry, git, gitOutput, modelFor,
  names, newRepository, newSpecRepository, orly, temporaryDirectory,
} from "./gates_test_support";

afterEach(cleanupTemporaryDirectories);

// The end-to-end walk drives the real command-line entry against real git
// repositories — several dozen spawns, whose wall time tracks machine load
// rather than anything the gates decide. Bun's 5s default made pre-commit red
// on a busy laptop while every assertion still held; the clock moves, the
// assertions do not.
const END_TO_END_TIMEOUT_MS = 30_000;

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

    expect(names(runGate(model, project, "work"))).toEqual(["git.branch", "git.tree", "repo.config"]);
    expect(names(runGate(model, project, "verify"))).toEqual(["cmd.conform", "cmd.verify.unit", "spec.dimensions"]);
    expect(names(runGate(model, project, "pr"))).toEqual([
      "docs.updated", "git.pushed", "git.tree", "spec.baseline", "spec.deferrals", "spec.dimensions", "spec.gate",
      "spec.moved", "spec.open-questions", "spec.ordering", "spec.product-clarity",
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

describe("repository resolution", () => {
  test("a linked worktree resolves the config its checkout committed", async () => {
    const project = newSpecRepository();
    const model = await modelFor(project);
    const worktree = join(temporaryDirectory(), "stream");
    git(project, "worktree", "add", "-q", "-b", "feat/stream", worktree);

    const config = runGate(model, worktree, "work").results.find((result) => result.name === "repo.config");

    expect(config?.ok).toBeTrue();
    expect(config?.detail).toBe("2 command(s) declared");
  });

  test("the declared commands run in the worktree, not in the main checkout", async () => {
    const project = newSpecRepository();
    const model = await modelFor(project, undefined, { conform: [["test", "-f", "stream-only.txt"]] });
    const worktree = join(temporaryDirectory(), "stream");
    git(project, "worktree", "add", "-q", "-b", "feat/stream", worktree);
    await Bun.write(join(worktree, "stream-only.txt"), "present only in the worktree\n");

    expect(runGate(model, worktree, "verify").results.find((result) => result.name === "cmd.conform")?.ok).toBeTrue();
    expect(runGate(model, project, "verify").results.find((result) => result.name === "cmd.conform")?.ok).toBeFalse();
  });

  test("a repository with no orly config is red, and names the install command", async () => {
    const project = newSpecRepository();
    const model = await modelFor(project);
    const stranger = newRepository();

    const config = runGate(model, stranger, "work").results.find((result) => result.name === "repo.config");

    expect(config?.ok).toBeFalse();
    expect(config?.detail).toContain("orly init");
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
  }, END_TO_END_TIMEOUT_MS);
});
