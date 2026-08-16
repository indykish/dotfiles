import { afterEach, describe, expect, test } from "bun:test";
import { mkdirSync } from "node:fs";
import { join } from "node:path";

import { activeSpecPath, runGate } from "./gates";
import {
  cleanupTemporaryDirectories, closedSpecRepository, git, modelFor,
  newRepository, newSpecRepository, SPEC_RELATIVE, specFixture,
} from "./gates_test_support";

afterEach(cleanupTemporaryDirectories);

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

describe("closed-spec follow-through", () => {
  test("a spec closed to done/ is discovered by its Branch: header and still gated", async () => {
    const project = closedSpecRepository("feat/closed");
    const model = await modelFor(project);

    const pr = runGate(model, project, "pr");
    expect(pr.results.find((result) => result.name === "spec.dimensions")?.detail).not.toContain("no active spec");
    expect(pr.results.find((result) => result.name === "spec.moved")?.ok).toBeTrue();
    expect(pr.results.find((result) => result.name === "spec.ordering")?.ok).toBeTrue();
    expect(pr.results.find((result) => result.name === "spec.baseline")?.ok).toBeTrue();
  });

  test("Status: DONE while the spec still lives under active/ is red on spec.moved", async () => {
    const project = newRepository();
    const model = await modelFor(project);
    git(project, "checkout", "-q", "-b", "feat/undone");
    mkdirSync(join(project, "docs/v1/active"), { recursive: true });
    await Bun.write(join(project, SPEC_RELATIVE), specFixture("DONE", "feat/undone"));
    git(project, "add", ".");
    git(project, "commit", "-q", "-m", "chore: spec says done but never moved");

    const moved = runGate(model, project, "pr").results.find((result) => result.name === "spec.moved");
    expect(moved?.ok).toBeFalse();
    expect(moved?.detail).toContain("still lives under active/");
  });

  test("code committed before the spec is red on spec.ordering", async () => {
    const project = newRepository();
    const model = await modelFor(project);
    git(project, "checkout", "-q", "-b", "feat/rush");
    await Bun.write(join(project, "src/rushed.ts"), "export const RUSHED = 1;\n");
    git(project, "add", ".");
    git(project, "commit", "-q", "-m", "feat: code before any spec");
    mkdirSync(join(project, "docs/v1/active"), { recursive: true });
    await Bun.write(join(project, SPEC_RELATIVE), specFixture("IN_PROGRESS", "feat/rush"));
    git(project, "add", ".");
    git(project, "commit", "-q", "-m", "chore: spec arrives late");

    const ordering = runGate(model, project, "pr").results.find((result) => result.name === "spec.ordering");
    expect(ordering?.ok).toBeFalse();
    expect(ordering?.detail).toContain("carries no spec file");
  });

  test("a deferral claim needs the Indy ack quote", async () => {
    const bare = closedSpecRepository("feat/defer", ["- Dimension 1.2 was deferred to follow-up"]);
    const bareModel = await modelFor(bare);
    const red = runGate(bareModel, bare, "pr").results.find((result) => result.name === "spec.deferrals");
    expect(red?.ok).toBeFalse();
    expect(red?.detail).toContain("agent-unilateral");

    const acked = closedSpecRepository("feat/defer", [
      "- Dimension 1.2 was deferred to follow-up",
      '> Indy (2026-08-11 09:00): "defer 1.2, ship the rest" — context: fixture',
    ]);
    const ackedModel = await modelFor(acked);
    expect(runGate(ackedModel, acked, "pr").results.find((result) => result.name === "spec.deferrals")?.ok).toBeTrue();
  });
});
