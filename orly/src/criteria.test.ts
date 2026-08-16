import { afterEach, describe, expect, test } from "bun:test";
import { rmSync } from "node:fs";
import { join } from "node:path";

import { criteriaFor, runCommand } from "./criteria";
import { cleanupTemporaryDirectories, modelFor, newRepository, newSpecRepository } from "./gates_test_support";

const WORK = "work";
const VERIFY = "verify";
const PR = "pr";
const REPO_CONFIG = "repo.config";

afterEach(cleanupTemporaryDirectories);

// criteriaFor is the composition point: gates.ts asks it what a named gate
// evaluates, so a criterion silently dropped from a group would be invisible
// to every other suite. These pin the membership of each group by name.
describe("criteriaFor", () => {
  async function contextFor(root: string) {
    return { root, model: await modelFor(root), acceptDirty: false };
  }

  function named(gate: string, context: Awaited<ReturnType<typeof contextFor>>): string[] {
    return criteriaFor(gate, context).map((criterion) => criterion.name).sort();
  }

  test("work evaluates the branch, the tree and the profile", async () => {
    const project = newSpecRepository();
    expect(named(WORK, await contextFor(project))).toEqual(["git.branch", "git.tree", REPO_CONFIG]);
  });

  test("verify pairs the spec dimensions with the fast command tier only", async () => {
    const project = newSpecRepository();
    const names = named(VERIFY, await contextFor(project));

    expect(names).toContain("spec.dimensions");
    expect(names).toContain("cmd.conform");
    // The slow tier belongs to the pr gate; leaking it here would make every
    // verify run pay for integration and memory suites.
    expect(names).not.toContain("cmd.verify.integration");
  });

  test("pr carries every closed-spec follow-through criterion", async () => {
    const project = newSpecRepository();
    const names = named(PR, await contextFor(project));

    for (const required of ["spec.moved", "spec.baseline", "spec.ordering", "spec.deferrals", "docs.updated"]) {
      expect(names).toContain(required);
    }
    // git.branch is a work-gate concern: by pr time the branch is established,
    // and re-asserting it would make an already-merged branch un-gateable.
    expect(names).not.toContain("git.branch");
  });

  test("an unknown gate name yields no criteria rather than throwing", async () => {
    const project = newSpecRepository();
    expect(criteriaFor("nonsense", await contextFor(project))).toEqual([]);
  });

  test("an unregistered repository still yields a red profile criterion on verify", async () => {
    const stranger = newRepository();
    const context = { root: stranger, model: await modelFor(newSpecRepository()), acceptDirty: false };

    const results = criteriaFor(VERIFY, context).map((criterion) => criterion.evaluate(context));
    const config = results.find((result) => result.name === REPO_CONFIG);
    expect(config?.ok).toBeFalse();
    expect(config?.detail).toContain("orly init");
  });
});

// Reproduces the pre-push hook inside a linked worktree: git exports GIT_DIR
// and friends to its hooks, and an inherited GIT_DIR pins every spawned git to
// the hook's repository. A linked worktree's .git is a file, so the pinned
// path is not even a directory and every criterion judged the wrong tree.
describe("git scope leaking from a hook environment", () => {
  test("criteria judge the handed path even with GIT_DIR exported", async () => {
    const project = newSpecRepository();
    const model = await modelFor(project);
    const context = { root: project, model, acceptDirty: false };
    const clean = criteriaFor(WORK, context).map((c) => c.evaluate(context));

    const saved = { ...process.env };
    process.env.GIT_DIR = ".git";
    process.env.GIT_INDEX_FILE = ".git/index";
    try {
      const polluted = criteriaFor(WORK, context).map((c) => c.evaluate(context));
      expect(polluted.map((r) => `${r.name}:${r.ok}`)).toEqual(clean.map((r) => `${r.name}:${r.ok}`));
    } finally {
      delete process.env.GIT_DIR; delete process.env.GIT_INDEX_FILE;
      Object.assign(process.env, saved);
    }
  });
});

describe("runCommand", () => {
  test("a zero exit reports ok with the exit-0 detail", () => {
    expect(runCommand(process.cwd(), ["true"])).toEqual({ ok: true, detail: "exit 0" });
  });

  test("a non-zero exit carries the code and the last output line", () => {
    const result = runCommand(process.cwd(), ["sh", "-c", "echo first; echo decisive >&2; exit 3"]);

    expect(result.ok).toBeFalse();
    expect(result.detail).toContain("exit 3");
    expect(result.detail).toEndWith("decisive");
  });

  test("a silent failure still reports a detail rather than an empty string", () => {
    const result = runCommand(process.cwd(), ["false"]);

    expect(result.ok).toBeFalse();
    expect(result.detail).toBe("exit 1: no output");
  });

  test("a missing binary is a failure, never a throw", () => {
    expect(runCommand(process.cwd(), ["orly-no-such-binary"]).ok).toBeFalse();
  });
});

describe("repo.config", () => {
  test("a repository with a config resolves its declared commands", async () => {
    const project = newSpecRepository();
    const context = { root: project, model: await modelFor(project), acceptDirty: false };
    const criterion = criteriaFor(WORK, context).find((entry) => entry.name === REPO_CONFIG);
    expect(criterion?.evaluate(context).ok).toBeTrue();
  });

  test("a repository with no config names the install command", async () => {
    const project = newSpecRepository();
    const context = { root: project, model: await modelFor(project), acceptDirty: false };
    rmSync(join(project, ".oracle/orly.json"));
    const criterion = criteriaFor(WORK, context).find((entry) => entry.name === REPO_CONFIG);
    const verdict = criterion?.evaluate(context);
    expect(verdict?.ok).toBeFalse();
    expect(verdict?.detail).toContain("orly init");
  });
});
